# prometheus でクラスターをモニタリングしてみよう

## prometheus とは

サーバのリソース状況やソフトウェアの統計情報といった各種メトリクスを収集して監視を行うモニタリングツールです

- https://prometheus.io/

## install 手順

Helm を使った install 方法(例)です

- [`WARNING`] この手順は Persistent Volume を使わない手順になっていますので、Pod の再起動で設定は消えてしまいますのでご注意ください
- 手順では `monitoring` という namespace に install しますが、適宜変えて問題ありません
- `kube-state-metrics`、`prometheus`、`grafana` の 3 つの chart を install します
 
### helm client のインストール

- brew や apt でインストールすることができます
- [こちら](https://helm.sh/docs/intro/install/)を参考に install してください

### helm repo の追加

3 つ追加しておきます

```bash
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo add grafana https://grafana.github.io/helm-charts
```

### kube-state-metrics

```bash
# config を作成
$ helm show values stable/kube-state-metrics > kube-state-metrics-values.yaml

# image を置き換え
$ vi kube-state-metrics-values.yaml
---
@@ -1,9 +1,9 @@
 # Default values for kube-state-metrics.
 prometheusScrape: true
 image:
-  repository: quay.io/coreos/kube-state-metrics
+  repository: makocchi/kube-state-metrics-arm64
   tag: v1.9.7
   pullPolicy: IfNotPresent

 imagePullSecrets: []
 # - name: "image-pull-secret"
---

# kube-state-metrics install
$ helm install kube-state-metrics stable/kube-state-metrics -f kube-state-metrics-values.yaml --namespace monitoring --create-namespace
```

### prometheus

```bash
# config を作成
$ helm show values prometheus-community/prometheus > prometheus-values.yaml

# kube-state-metrics を disable
# alert-manager と prometheus server の persistentVolume の無効化
$ vi prometheus-values.yaml
---
@@ -175,11 +175,11 @@

   persistentVolume:
     ## If true, alertmanager will create/use a Persistent Volume Claim
     ## If false, use emptyDir
     ##
-    enabled: true
+    enabled: false

     ## alertmanager data Persistent Volume access modes
     ## Must match those of existing PV or dynamic provisioner
     ## Ref: http://kubernetes.io/docs/user-guide/persistent-volumes/
     ##
@@ -403,11 +403,11 @@
     resources: {}

 kubeStateMetrics:
   ## If false, kube-state-metrics sub-chart will not be installed
   ##
-  enabled: true
+  enabled: false

 ## kube-state-metrics sub-chart configurable values
 ## Please see https://github.com/helm/charts/tree/master/stable/kube-state-metrics
 ##
 # kube-state-metrics:
@@ -771,11 +771,11 @@

   persistentVolume:
     ## If true, Prometheus server will create/use a Persistent Volume Claim
     ## If false, use emptyDir
     ##
-    enabled: true
+    enabled: false

     ## Prometheus server data Persistent Volume access modes
     ## Must match those of existing PV or dynamic provisioner
     ## Ref: http://kubernetes.io/docs/user-guide/persistent-volumes/
     ##
---

# prometheus install
$ helm install prometheus prometheus-community/prometheus -f prometheus-values.yaml --namespace monitoring --create-namespace
```

### grafana

```bash
# config を作成
$ helm show values grafana/grafana > grafana-values.yaml

# service は NodePort に変更
# adminPassword は適当に
$ vi grafana-values.yaml
---
@@ -114,11 +114,11 @@
 ## Expose the grafana service to be accessed from outside the cluster (LoadBalancer service).
 ## or access it from within the cluster (ClusterIP service). Set the service type and the port to serve it.
 ## ref: http://kubernetes.io/docs/user-guide/services/
 ##
 service:
-  type: ClusterIP
+  type: NodePort
   port: 80
   targetPort: 3000
     # targetPort: 4181 To be used with a proxy extraContainer
   annotations: {}
   labels: {}
@@ -261,11 +261,11 @@
   #    memory: 128Mi


 # Administrator credentials when not using an existing secret (see below)
 adminUser: admin
-# adminPassword: strongpassword
+adminPassword: admin

 # Use an existing secret for the admin user.
 admin:
   existingSecret: ""
   userKey: admin-user
---

# grafana install
$ helm install grafana grafana/grafana -f grafana-values.yaml --namespace monitoring
```

### grafana の設定

- NodePort 経由で graafna にアクセスし、Data Sources の設定で Prometheus を選択し、`http://prometheus-server.monitoring.svc.cluster.local` を入れる
- dashboard はなんか適当に探してみよう
  - https://grafana.com/grafana/dashboards?dataSource=prometheus&search=kubernetes&orderBy=reviewsAvgRating&direction=desc
  - https://grafana.com/grafana/dashboards/7249 とか分かりやすいかも

