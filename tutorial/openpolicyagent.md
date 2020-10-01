# OpenPolicyAgent を使って、Kubernetesのリソース作成を制御してみよう

## OpenPolicyAgent とは
OpenPolicAgent(https://www.openpolicyagent.org/docs/latest/) はオープンソースの軽量、プラットフォームを選ばない汎用的なポリシーエンジンです。

「誰が何をする」というポリシーをコードとして管理する(Policy as Code)のための言語Regoと、ポリシーの評価を行うエンジンが提供されています。

詳しくは公式サイトを確認してください

- https://www.openpolicyagent.org/

## 動作環境
本チュートリアルは2020/10/01現在の OPA ver2.32.2 と Kubernetes ver1.18.5 で動作することを確認しています。

## OPAのインストール

Kubernetes のポリシーを評価するエンジンをインストールしていきます

### Namespaceの作成

```
kubectl create namespace opa
```

作成した Namespace でこれ以降の作業を行いますので下記のコマンドで Namespace の切り替えを行ってください

```
kubectl config set-context $(kubectl config current-context) --namespace=opa
```

### TLS証明書の作成
OPA と Kubernetes の通信はTLSを用いて行われます。
そのために `openssl` コマンドを用いていわゆるオレオレ証明書を作成していきます。

```shell
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -days 100000 -out ca.crt -subj "/CN=admission_ca"
```

これらの鍵を用いてTLS鍵と証明書を作成していきます

```shell
cat >server.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOF
```

```shell
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=opa.opa.svc" -config server.conf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 100000 -extensions v3_req -extfile server.conf
```

注意すべきは `"/CN=opa.opa.svc"` この Common Name が Kubernetes のコントロールプレーンが OPA と通信するために、そのサービスドメインと一致するようにしなくてはいけません。 

Kubernetes の Secret リソースとしてTLS証明書を作成します

```
kubectl create secret tls opa-server --cert=server.crt --key=server.key
```

次に下記の yaml を用いて、OPA の Admission Controller を作成します

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: opa-viewer
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:serviceaccounts:opa
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: opa
  name: configmap-modifier
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: opa
  name: opa-configmap-modifier
roleRef:
  kind: Role
  name: configmap-modifier
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:serviceaccounts:opa
  apiGroup: rbac.authorization.k8s.io
---
kind: Service
apiVersion: v1
metadata:
  name: opa
  namespace: opa
spec:
  selector:
    app: opa
  ports:
  - name: https
    protocol: TCP
    port: 443
    targetPort: 443
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: opa
  namespace: opa
  name: opa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opa
  template:
    metadata:
      labels:
        app: opa
      name: opa
    spec:
      containers:
        - name: opa
          image: bo0km4n1109/opa:v0.23.2-arm64
          args:
            - "run"
            - "--server"
            - "--tls-cert-file=/certs/tls.crt"
            - "--tls-private-key-file=/certs/tls.key"
            - "--addr=0.0.0.0:443"
            - "--addr=http://127.0.0.1:8181"
            - "--log-format=json-pretty"
            - "--set=decision_logs.console=true"
          volumeMounts:
            - readOnly: true
              mountPath: /certs
              name: opa-server
          readinessProbe:
            httpGet:
              path: /health?plugins&bundle
              scheme: HTTPS
              port: 443
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              scheme: HTTPS
              port: 443
            initialDelaySeconds: 3
            periodSeconds: 5
        - name: kube-mgmt
          image: bo0km4n1109/kube-mgmt:0.10-arm64
          args:
            - "--replicate-cluster=v1/namespaces"
            - "--replicate=extensions/v1beta1/ingresses"
      volumes:
        - name: opa-server
          secret:
            secretName: opa-server
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: opa-default-system-main
  namespace: opa
data:
  main: |
    package system

    import data.kubernetes.admission

    main = {
      "apiVersion": "admission.k8s.io/v1beta1",
      "kind": "AdmissionReview",
      "response": response,
    }

    default uid = ""

    uid = input.request.uid

    response = {
        "allowed": false,
        "uid": uid,
        "status": {
            "reason": reason,
        },
    } {
        reason = concat(", ", admission.deny)
        reason != ""
    }
    else = {"allowed": true, "uid": uid}
```

使用するコンテナイメージは arm64 用にビルドしたものを用いています。
別の Kubernetes 環境で利用する際は適宜変更してください。

次に下記のコマンドを実行して特定のリソースが作成された際に、 OPA にそのリソースの内容を通知する Webhook のコンフィグを作成します

```shell
cat > webhook-configuration.yaml <<EOF
kind: ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1beta1
metadata:
  name: opa-validating-webhook
webhooks:
  - name: validating-webhook.openpolicyagent.org
    namespaceSelector:
      matchExpressions:
      - key: openpolicyagent.org/webhook
        operator: NotIn
        values:
        - ignore
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources: ["*"]
    clientConfig:
      caBundle: $(cat ca.crt | base64 | tr -d '\n')
      service:
        namespace: opa
        name: opa
EOF
```

今回は opa と kube-system では OPA によるポリシーを無効化します。

```shell
kubectl label ns kube-system openpolicyagent.org/webhook=ignore
kubectl label ns opa openpolicyagent.org/webhook=ignore
```

最後に、先ほど作成した Webhook の yaml を適用していきます。

```
kubectl apply -f webhook-configuration.yaml
```

OPA のログは下記のコマンドで確認できます。
リクエストとそれに対するレスポンスのステータスを表示しますが、400系エラーや、証明書のエラーがでていなければ問題ありません

```
kubectl logs -l app=opa -c opa -f
```

## Rego によるポリシーの作成

今回は Deployment リソースの作成をあるルールに基づいて制限してみます

```go
package kubernetes.admission

import data.kubernetes.namespaces

deny[msg] {
    input.request.kind.kind = "Deployment"
    input.request.operation = "CREATE"
    name := input.request.object.metadata.name
    contains(name, "bad")
    msg := sprintf("invalid deployment name=%q", [name])
}
```

このポリシーによる評価ルールは単純です。
Deployment の名前に `bad` が含まれていたら作成を拒否するというものです。

このポリシーから ConfigMap を作成します。

```
kubectl create configmap deny-create-bad-deploy --from-file=deny-create-bad-deploy.rego
```

ConfigMap を describe すると、`openpolicyagent.org/policy-status: '{"status":"ok"}'` という Annotation が付与されていれば、ポリシーが OPA によって認識されています。

最後に、下記コマンドで `bad` が含まれる名前の Deployment を作成してみます

```shell
kubectl create -n default deployment bad-deployment --image nginx
```

実行後に下記のようなエラーが出力されれば成功です。

```
Error from server (invalid deployment name="bad-deployment"): error when creating "deployment.yaml": admission webhook "validating-webhook.openpolicyagent.org" denied the request: invalid deployment name="bad-deployment"
```

## Kubernetes 1.19.2 におけるトラブルシューティング
Kubernetes 1.19.2 は Go 1.15 によりビルドされていますが、本チュートリアルを 1.19.2 のクラスタで行う場合下記のようなエラーが kube-apiserver で発生する可能性があります。

```
Error from server (InternalError): error when creating "qa-namespace.yaml": Internal error occurred: failed calling webhook "validating-webhook.openpolicyagent.org": Post "https://opa.opa.svc:443/?timeout=10s": x509: certificate relies on legacy Common Name field, use SANs or temporarily enable Common Name matching with GODEBUG=x509ignoreCN=0
```

こちらは、Go 1.15 によるTLS認証周りの処理が変わったことによるものです。
なので、kube-apiserver が動作している環境変数に `GODEBUG=x509ignoreCN=0` を定義することによってこのエラーは解消されます。

kubeadm で構築していた場合、master ノードの `/etc/kubernetes/manifests/kube-apiserver.yaml` に下記のように追記してあげれば大丈夫です。

```
image: k8s.gcr.io/kube-apiserver:v1.19.2
imagePullPolicy: IfNotPresent
# 追記
env:
 - name: GODEBUG
   value: "x509ignoreCN=0"
```

Hardway で構築していた場合は、systemd の unit ファイルを下記のように更新します

```
$ sudo vi /etc/systemd/system/kube-apiserver.service
...
[Service]
Environment=GODEBUG=x509ignoreCN=0
...
$ sudo systemctl daemon-reload
$ sudo systemctl restart kube-apiserver
```

## 参考
- https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/
- https://thinkit.co.jp/article/17511