# kubeadm

kubeadmはKubernetes公式が作っている、Kubernetesのインストールツールです。
クラスタ上に何かを構築したい方は、kubeadmを使ってクラスタを簡単に構築してしまってから、その上で何かを作っていきましょう。

今回は3台のノードを下記のように利用します。

* Master Node
	* k8s1
* Worker Node
	* k8s2
	* k8s3

## ホスト名の変更

各ノードのホスト名を設定してください。

```bash
hostnamectl set-hostname k8s1
# hostnamectl set-hostname k8s2
# hostnamectl set-hostname k8s3
```

## IPアドレスとホスト名の紐付け

払い出されたIPアドレスを元にホスト名で名前解決できるように、すべてのノードで/etc/hostsを設定します。

```bash
cat << _EOF_ | sudo tee -a /etc/hosts
10.0.0.11  k8s1
10.0.0.12  k8s2
10.0.0.13  k8s3
_EOF_
```

## Docker / Kubernetes を動作させるための設定

ブリッジインターフェースがホストのiptablesで処理されるように、カーネルパラメータを調整します。

```bash
# カーネルパラメータのっ変更
$ cat << _EOF_ | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
_EOF_

# 有効化
$ sudo sysctl --system
```

また、cgroups の Memory Subsystem を有効化します。今回インストールした OS ではこの Subsystem がデフォルトで無効化されているため有効にする必要があります。`/boot/firmware/cmdline.txt` に下記を追記して再起動してください。

```bash
cgroup_memory=1 cgroup_enable=memory
```

## 依存する関連パッケージなどのインストール

依存する関連パッケージなどをインストールします。

```bash
$ sudo apt-get update
$ sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common socat conntrack ipset
```

## Dockerのインストール

Dockerをインストールします。

```bash
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

$ sudo apt-get update
$ sudo apt-get -y install docker-ce=5:19.03.12~3-0~ubuntu-focal docker-ce-cli=5:19.03.12~3-0~ubuntu-focal containerd.io=1.2.13-2
```

## Kubernetesパッケージのインストール

```bash
$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << _EOF_ | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
_EOF_

$ sudo apt-get update
$ sudo apt-get install -y kubelet=1.19.2-00 kubeadm=1.19.2-00 kubectl=1.19.2-00
$ sudo apt-mark hold kubelet kubeadm kubectl
```

## Kubernetesクラスタの初期化

Master Nodeだけで初期化コマンドを実行します。
コマンド実行後は、このあとに実行するべきコマンドが出力されているので確認してください。

```bash
# Kubernetes クラスタの初期化（Master Node で実施）
$ kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=k8s1 --apiserver-cert-extra-sans=k8s1
...(省略)...
```

kubectlコマンドが利用する認証情報のファイルをデフォルトで読み込まれるパスにコピーします。

```bash
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Workerノードの組み込み

それ以外のWorker Nodeでクラスタへの参加コマンドを実行します。kubeadm init実行後に表示されるトークン情報を使ってkubeadm joinコマンドを実行してください。

```bash
# Kubernetesクラスタへの参加（Worker Node で実施）
$ kubeadm join k8s1:6443 --token 0vfaw7.kyroprtyc3vmle9m \
    --discovery-token-ca-cert-hash sha256:ef97cfdf5cbf93cbc39c0046e7e594af6aa20ffdc19de05c98269dd6aaedc610
```

## オーバーレイネットワークの展開

各ノードで実行されるPod同士が通信できるように、Node間でオーバーレイネットワークを展開します。
これにより、PodとPodがノードを超えても通信できるようになります。
Kubernetesでオーバーレイネットワークを展開するには、CNIプラグインを使います。
CNI Pluginはいくつかありますが、今回はarmで動かしやすいFlannelを利用します。

```bash
# Flannelでオーバーレイネットワークの展開	
$ kubectl apply -f \
    https://raw.githubusercontent.com/coreos/flannel/v0.12.0/Documentation/kube-flannel.yml
```

## Kubernetesクラスタの状態確認

クラスタに3台のノードが組み込まれており、正常に動作しているか確認してください。

```bash
$ kubectl get nodes
NAME   STATUS   ROLES    AGE     VERSION
k8s1   Ready    master   9m21s   v1.19.2
k8s2   Ready    <none>   28s     v1.19.2
k8s3   Ready    <none>   24s     v1.19.2

$ kubectl cluster-info
Kubernetes master is running at https://k8s1:6443
KubeDNS is running at https://k8s1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

この他にも、実際にPodなどをデプロイして動くかを確認したり、Serviceリソース（type: ClsuterIP）が利用できるかを確認しておくと良いでしょう。

