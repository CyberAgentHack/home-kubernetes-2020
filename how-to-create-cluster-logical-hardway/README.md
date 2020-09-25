みなさんクラスタの組み立ては終わりましたか？

ここからは Kubernetes を構築していきましょう。

### NOTES

 本手順は [kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) をもとに Raspberry Pi 用 + このインターン用に書いたものです。
 
 サービスの起動やその他 Kubernetes に関係ないコマンドは書いてなかったりするため少しだけ気をつけてください。文としては明記してあります。

## 準備

まずいくつか決め事をしましょう。具体的にはネットワークとホスト名です。

### ネットワーク

ネットワークは Node 用サブネット・Pod 用サブネット・ClusterIP 用サブネットの 3 つを決めます。今回の手順では iptables を利用して Kubernetes 間の通信制御を行うので、Pod 用サブネットは Node の台数分決めます。

私の環境では次のように決めました。

- Node 用サブネット
  - `10.0.0.0/24`
    - Node1: `10.0.0.11`
    - Node2: `10.0.0.12`
    - Node3: `10.0.0.13`
- Pod 用サブネット
  - `10.1.0.0/24`
  - `10.2.0.0/24`
  - `10.3.0.0/24`
- ClusterIP 用サブネット
  - `10.32.0.0/24`

インターフェースが無線 LAN と Ethernet の 2 種類があるので、Node 用のネットワーク (Kubernetes 間の通信) と外側のネットワークは別々にしても良いでしょう。本インターンで使用する Ubuntu ではネットワークの設定管理を Netplan というものに任せているので、Wi-Fi の設定がしたい場合はそのあたりを調べてみてください。

#### NOTES

ネットワークの設定には 2 つのルートがあります。

1 つが家庭内ネットワークから DHCP で振られた IP をそのまま Node 用サブネットとするルートです。例えば家のネットワークアドレスが `192.168.1.0/24` ならば次のようになります。この場合外向きのトラフィックとクラスタ間のトラフィックは同じネットワークを通ります。

- Node 用サブネット (例)
  - `192.168.1.0/24`
    - Node1: `192.168.1.117`
    - Node2: `192.168.1.118`
    - Node3: `192.168.1.119`

もう 1 つが Kubernetes のクラスタ間通信を完全に分離するルートです。このルートでは家のネットワークを無線 LAN (Wi-Fi) で受けて、クラスタ間通信は Ethernet (物理ポート) で行います。こうすると少し設定は複雑になりますが、クラスタ間の通信が家のネットワークを通らないので、少しですがネットワーク機器に掛かる負荷を下げることができます。また、無線 LAN だけを利用する (LAN 線を伸ばしておくのは取り回しがしづらいので将来的に Wi-Fi を使いたいですよね) 場合と比べてレイテンシを小さくすることができます。効果としては微小ですが構成としてはきれいになるでしょう。例としては次のような感じです (私の環境はこっちです)。

- Node 用サブネット (例)
  - Ethernet
  - `10.0.0.0/24`
    - Node1: `10.0.0.11`
    - Node2: `10.0.0.12`
    - Node3: `10.0.0.13`
- Node 外部通信用サブネット (例)
  - 無線 LAN
  - `192.168.1.0/24`
    - Node1: `192.168.1.117`
    - Node2: `192.168.1.118`
    - Node3: `192.168.1.119`

### ホスト名

ホスト名は決めなくても問題はないですがターミナルに入ったときにわかりやすくするためにも設定しておいたほうが良いでしょう。Kubernetes の Master となる Node も決定します。

- Node1: `k8s1` (Master)
- Node2: `k8s2`
- Node3: `k8s3`

決め終わったら `hostnamectl` で設定しておきます。`/etc/hosts` にも書いておくと他の Node に ssh するときに楽です。

### その他

このような初期設定が終わったり、何か区切りの良い地点まで到達したら SD カードのイメージを保存しておくと何かおかしくなったときにすぐにリカバリすることができます。バックアップの仕方は何でも良いですが、Win32 Disk Imager などを使うと簡単にイメージが作成できます。

## 証明書の生成

Kubernetes では各コンポーネントやコマンドラインツールとの通信に TLS を使用します。この項目ではそれに使用する証明書類を生成します。

まず証明書の生成に使用するツールをインストール・ダウンロードします。

```sh
sudo apt install -y golang-cfssl

# Download generate-cert.sh from https://github.com/CyberAgentHack/home-kubernetes-2020/blob/master/how-to-create-cluster-logical-hardway/generate-cert.sh
chmod +x generate-cert.sh
```

証明書を生成します。結果は `cert` ディレクトリに出力されます。中で何をしているか気になる方はスクリプトの中身を覗いてみてください。

```sh
./generate-cert.sh
# Hostname of Node1: k8s1
# Hostname of Node2: k8s2
# Hostname of Node3: k8s3
# Addresses of Node1 (x.x.x.x[,x.x.x.x]): 10.0.0.11,192.168.136.176
# Addresses of Node2 (x.x.x.x[,x.x.x.x]): 10.0.0.12,192.168.136.177
# Addresses of Node3 (x.x.x.x[,x.x.x.x]): 10.0.0.13,192.168.136.178
# Address of Kubernetes ClusterIP (first address of ClusterIP subnet): 10.32.0.1
# ...
# ...
# ---> Complete to generate certificate
```

できあがった `ca.pem` と各ホストに対応した `<hostname>.pem` と `<hostname>-key.pem` はそれぞれのホストに `scp` などで送ってください。これらは Kubelet によって使用されます。他の証明書は Master Node で使用されます。

## Kubeconfig の生成

各種コンポーネントが kube-apiserver と通信するための Kubernetes 用設定ファイルを生成します。

```sh
wget https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/arm64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin

# Download generate-kubeconfig.sh from https://github.com/CyberAgentHack/home-kubernetes-2020/blob/master/how-to-create-cluster-logical-hardway/generate-kubeconfig.sh
chmod u+x generate-kubeconfig.sh
```

Kubeconfig を生成します。結果は `kubeconfig` ディレクトリに出力されます。

```sh
./generate-kubeconfig.sh
# Hostname of Node1: k8s1
# Hostname of Node2: k8s2
# Hostname of Node3: k8s3
# Address of Master Node: 10.0.0.11
# ...
# ...
# ---> Complete to generate kubeconfig
```

できあがった `<hostname>.kubeconfig` と `kube-proxy.kubeconfig` はそれぞれのホストに送ってください。

## etcd のデプロイ (Master)

Kubernetes で利用されるデータは基本的に etcd で管理されています。この項目では etcd を実際に動かせるようにしていきます。この見出しのように `Master` と付いているものは、Kubernetes Master のための手順です。そのため全ての Raspberry Pi で実行する必要はありません。

バイナリを用意します。

```sh
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-arm64.tar.gz"
tar -xvf etcd-v3.4.13-linux-arm64.tar.gz
sudo mv etcd-v3.4.13-linux-arm64/etcd* /usr/local/bin/
```

設定ファイルの領域の作成や、証明書の配置を行います。

```sh
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd
sudo cp ~/cert/ca.pem ~/cert/kubernetes-key.pem ~/cert/kubernetes.pem /etc/etcd/
```

etcd を動かすためのユニットファイルを作成します。作成したら起動してください。起動の仕方は `systemctl` コマンドで行います。

```sh
ETCD_NAME="<etcd_name>"
INTERNAL_IP="<master_ip>"

# ETCD_UNSUPPORTED_ARCH を取り除いても良いかも
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-initial-token \\
  --initial-cluster ${ETCD_NAME}=https://${INTERNAL_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
Environment=ETCD_UNSUPPORTED_ARCH=arm64

[Install]
WantedBy=multi-user.target
EOF

```
etcdをシステム起動時に実行するようにします。また即時に起動させ状態を確認します。
Active: activeとなっているか確認しましょう
```
sudo systemctl enable etcd.service
sudo systemctl start etcd.service
sudo systemctl status etcd.service

● etcd.service - etcd
     Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: enabled)
     Active: active (running) since Fri 2020-09-25 02:10:10 UTC; 27s ago
       Docs: https://github.com/coreos
   Main PID: 4309 (etcd)
      Tasks: 13 (limit: 9258)
     CGroup: /system.slice/etcd.service
             └─4309 /usr/local/bin/etcd --name rpi4-master1 --cert-file=/etc/etcd/kubernetes.pem --key-file=/etc/etcd/kubernetes-key.pem --peer-cert-file=/etc/etcd/kubernetes.pem --peer-key-file=/etc/etcd/kubernetes-key.pem --trusted-c>

Sep 25 02:10:10 rpi4-node1 etcd[4309]: raft2020/09/25 02:10:10 INFO: raft.node: 84f8b1eba3d10230 elected leader 84f8b1eba3d10230 at term 2
Sep 25 02:10:10 rpi4-node1 etcd[4309]: setting up the initial cluster version to 3.4
Sep 25 02:10:10 rpi4-node1 etcd[4309]: set the initial cluster version to 3.4
Sep 25 02:10:10 rpi4-node1 etcd[4309]: published {Name:rpi4-master1 ClientURLs:[https://192.168.11.14:2379]} to cluster f4b27d1154aa4089
Sep 25 02:10:10 rpi4-node1 etcd[4309]: ready to serve client requests
Sep 25 02:10:10 rpi4-node1 etcd[4309]: enabled capabilities for version 3.4
Sep 25 02:10:10 rpi4-node1 etcd[4309]: ready to serve client requests
Sep 25 02:10:10 rpi4-node1 systemd[1]: Started etcd.
Sep 25 02:10:10 rpi4-node1 etcd[4309]: serving client requests on 192.168.11.14:2379
Sep 25 02:10:10 rpi4-node1 etcd[4309]: serving client requests on 127.0.0.1:2379
```

動作確認を行います。コメントのような出力が得られれば OK です。

```sh
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
  
# -> e67187a477e79e67, started, k8s1, https://10.0.0.11:2380, https://10.0.0.11:2379, false
```

## kube-apiserver のデプロイ (Master)

kube-apiserver は Kubernetes の中核を担うコンポーネントです。この項目では kube-apiserver を実際に動かせるようにしていきます。

バイナリを用意します。

```sh
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/arm64/kube-apiserver"
chmod +x kube-apiserver
sudo mv kube-apiserver /usr/local/bin/
```

etcd の[データを暗号化する機能](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)のための設定ファイルを生成します。

```sh
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

設定ファイルの領域の作成や、証明書の配置を行います。

```sh
sudo mkdir -p /etc/kubernetes/config
sudo mkdir -p /var/lib/kubernetes/
sudo cp -ai ~/cert/ca.pem ~/cert/ca-key.pem ~/cert/kubernetes-key.pem ~/cert/kubernetes.pem \
  ~/cert/service-account-key.pem ~/cert/service-account.pem /var/lib/kubernetes/
sudo cp -ai encryption-config.yaml /var/lib/kubernetes/
```

kube-apiserver を動かすためのユニットファイルを作成します。作成したら起動してください。

```sh
INTERNAL_IP="<master_ip>"
CLUSTER_IP_NETWORK="<cluster_ip_network>"

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://${INTERNAL_IP}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=${CLUSTER_IP_NETWORK} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## kube-controller-manager のデプロイ (Master)

kube-controller-manager は Kubernetes におけるリソース管理などのコントローラー類を束ねたコンポーネントです。この項目では kube-controller-manager を実際に動かせるようにしていきます。

バイナリを用意します。

```sh
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/arm64/kube-controller-manager"
chmod +x kube-controller-manager
sudo mv kube-controller-manager /usr/local/bin/
```

Kubeconfig の配置を行います。

```sh
sudo cp -ai kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

kube-controller-manager を動かすためのユニットファイルを作成します。作成したら起動してください。

```sh
NODE_NETWORK="<node_network>"
CLUSTER_IP_NETWORK="<cluster_ip_network>"

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${NODE_NETWORK} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${CLUSTER_IP_NETWORK} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## kube-scheduler のデプロイ (Master)

kube-scheduler は Pod のスケジューリングを担うコンポーネントです。この項目では kube-scheduler を実際に動かせるようにしていきます。

バイナリを用意します。

```sh
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/arm64/kube-scheduler"
chmod +x kube-scheduler
sudo mv kube-scheduler /usr/local/bin/
```

Kubeconfig の配置を行います。

```sh
sudo cp -ai kube-scheduler.kubeconfig /var/lib/kubernetes/
```

kube-scheduler を動かすためのユニットファイルを作成します。作成したら起動してください。

```sh
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Master の動作チェック

Master のコンポーネントを起動し終えたら問題なく認識されているかどうか確認をしてください。

```sh
kubectl get componentstatuses --kubeconfig admin.kubeconfig
# NAME                 STATUS    MESSAGE             ERROR
# scheduler            Healthy   ok
# controller-manager   Healthy   ok
# etcd-0               Healthy   {"health":"true"}
```

## Kubernetes Node 構築の前準備 (Node)

今までは Kubernetes Master の構築を行ってきましたが、ここからは Kubernetes Node (Pod のための Worker) の構築を行っていきます。この見出しのように `Node` と付いているものは、Kubernetes Node のための手順です。そのため全ての Raspberry Pi で実行する必要があります。

まず cgroups の Memory Subsystem を有効化します。今回インストールした OS ではこの Subsystem がデフォルトで無効化されているため有効にする必要があります。`/boot/firmware/cmdline.txt` に下記を追記して再起動してください。

```sh
cgroup_memory=1 cgroup_enable=memory
```

依存関係のあるパッケージをインストールします。

```sh
sudo apt update
sudo apt -y install socat conntrack ipset
```

## kubelet のデプロイ (Node)

kubelet は Pod を動かすためのコンポーネントです。今回の手順ではコンテナランタイムに containerd を採用しています。

設定ファイルの領域の作成や、証明書などの配置を行います。

```sh
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kubernetes \
  /etc/containerd

sudo cp -ai ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
sudo cp -ai ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp -ai ca.pem /var/lib/kubernetes/
```

バイナリを用意します。

```sh
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.18.0/crictl-v1.18.0-linux-arm64.tar.gz \
  https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-arm64-v0.8.6.tgz \
  https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/arm64/kubelet
tar -xvf crictl-v1.18.0-linux-arm64.tar.gz
sudo tar -xvf cni-plugins-linux-arm64-v0.8.6.tgz -C /opt/cni/bin/
chmod +x crictl kubelet
sudo mv crictl kubelet /usr/local/bin/

sudo apt -y install containerd runc
```

Pod ネットワークの設定をします。今回は Node によって Pod のネットワークが異なるので CIDR を変えつつ実行してください。

```sh
POD_CIDR=<your_pod_network>

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
```

containerd の設定をします。Low Level なコンテナランタイムには runC を利用します。

```sh
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/sbin/runc"
      runtime_root = ""
EOF
```

kubelet の設定ファイルとユニットファイルを作成します。作成したら起動してください。

```sh
POD_CIDR=<your_pod_network>

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF


cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## kube-proxy のデプロイ (Node)

kube-proxy は Kubernetes のネットワークを制御するためのコンポーネントです。今回の手順では iptables モードで動かします。

バイナリを用意します。

```sh
wget -q --show-progress --https-only --timestamping \
   https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/arm64/kube-proxy
chmod +x kube-proxy
sudo mv kube-proxy /usr/local/bin/
```

設定ファイルの領域の作成や、Kubeconfig の配置を行います。

```sh
sudo mkdir -p /var/lib/kube-proxy
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

kube-proxy の設定ファイルとユニットファイルを作成します。作成したら起動してください。

```sh
NODE_NETWORK="<node_network>"

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${NODE_NETWORK}"
EOF


cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## ルーティング設定の追加

今回は iptables を利用した Pod ネットワークであるため、Node は自身以外の Pod ネットワークを知りません。そこで他の Node へのルーティング情報を与えてあげます。

```sh
# Node1 の場合
sudo ip route add 10.2.0.0/24 via 10.0.0.12 dev eth0
sudo ip route add 10.3.0.0/24 via 10.0.0.13 dev eth0
```

## kubelet の kube-apiserver 認証 RBAC 設定

kubelet が kube-apiserver からの接続を許可するように設定します。

```sh
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## Node の動作チェック

Node のコンポーネントを起動し終えたら問題なく kube-apiserver に認識されているかどうか確認してください。

```sh
kubectl get node
# NAME   STATUS   ROLES    AGE   VERSION
# k8s1   Ready    <none>   13s   v1.19.2
# k8s2   Ready    <none>   13s   v1.19.2
# k8s3   Ready    <none>   13s   v1.19.2
```

## クラスタ内 DNS のデプロイ

[クラスタ内部の名前解決](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)を行うために CoreDNS をデプロイします。

```sh
# Download coredns-1.7.0.yaml from https://github.com/CyberAgentHack/home-kubernetes-2020/blob/master/how-to-create-cluster-logical-hardway/coredns-1.7.0.yaml
kubectl apply -f coredns-1.7.0.yaml

kubectl run test --image busybox:1.28 --restart Never -it --rm -- nslookup kubernetes
# Name:      kubernetes
# Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local

kubectl run test --image busybox:1.28 --restart Never -it --rm -- nslookup google.com
# Name:      google.com
# Address 1: 2404:6800:4004:80a::200e xxx.xxx.net
# Address 2: 172.217.26.14 xxx.xxx.net
```

## 最終動作チェック

最後に Kubernetes がちゃんと機能しているかどうかチェックを行います。

Secret が暗号化されて保存されていることを確認します。本来は base64 encoded な値が表示されますが、そうでない暗号化されたデータが見えれば OK です。

```sh
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"
  
sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem \
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C
# 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
# 00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
# 00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
# 00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
# 00000040  3a 76 31 3a 6b 65 79 31  3a 94 12 51 21 fc b3 b9  |:v1:key1:..Q!...|
# 00000050  f6 59 ce 9b 3b 6c 2f 92  3d c7 6a e5 c2 be 69 91  |.Y..;l/.=.j...i.|
# 00000060  80 39 96 b0 d0 25 f2 c9  12 ab 2a 42 5d 72 0c 74  |.9...%....*B]r.t|
# 00000070  d7 b4 c5 57 56 d3 4b 5e  28 71 c9 34 49 4f b3 21  |...WV.K^(q.4IO.!|
# 00000080  a9 05 90 b7 1f 5b bd 03  67 0f 6f 4f c5 8b 68 aa  |.....[..g.oO..h.|
# 00000090  65 4d 49 3a 94 43 52 b8  af 44 f4 14 f1 07 b4 0b  |eMI:.CR..D......|
# 000000a0  78 87 30 c2 cb 17 8e 2d  b4 d0 6a a2 d8 ff 99 ba  |x.0....-..j.....|
# 000000b0  64 c4 f7 46 30 96 ae 31  15 03 73 3d 06 12 8f 71  |d..F0..1..s=...q|
# 000000c0  23 f5 a2 9f db 81 03 8b  37 c6 a1 76 48 b1 8c cc  |#.......7..vH...|
# 000000d0  49 3b a6 aa bf 60 2e 8b  34 2c 6c 7b c7 60 7b 4a  |I;...`..4,l{.`{J|
# 000000e0  cc f4 f4 8c c1 36 c4 1d  4c f2 64 4d 17 3e bd f2  |.....6..L.dM.>..|
# 000000f0  fc 12 e8 6c c7 23 0b f0  4b e0 3a 26 18 83 fd 30  |...l.#..K.:&...0|
# 00000100  b7 52 b8 a0 99 f8 c0 b2  ba a4 f7 3a ae 1f de ee  |.R.........:....|
# 00000110  60 a7 c6 8a 77 48 bc 76  ec 26 ef e3 a3 c8 3b 29  |`...wH.v.&....;)|
# 00000120  6f fd 66 3a a4 b2 3a 94  b0 77 ba 3f 3f 80 0c a0  |o.f:..:..w.??...|
# 00000130  8d 43 b1 57 43 87 3e df  d5 51 67 04 2b d6 b9 3e  |.C.WC.>..Qg.+..>|
# 00000140  e8 84 07 ba c5 e5 7b be  59 0a                    |......{.Y.|
# 0000014a
```

Pod が起動できることを確認します。上の CoreDNS のデプロイで確認はできていると思いますが、一応します。

```sh
kubectl create deployment nginx --image=nginx
kubectl get pods -l app=nginx
# NAME                    READY   STATUS    RESTARTS   AGE
# nginx-f89759699-t9vkd   1/1     Running   0          61s
```

Port Forwarding が機能することを確認します。

```sh
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8081:80
# Forwarding from 127.0.0.1:8081 -> 80
# Forwarding from [::1]:8081 -> 80
# Handling connection for 8081

curl --head http://127.0.0.1:8081
# HTTP/1.1 200 OK
# Server: nginx/1.19.2
# Date: Tue, 22 Sep 2020 17:56:09 GMT
# Content-Type: text/html
# Content-Length: 612
# Last-Modified: Tue, 11 Aug 2020 14:50:35 GMT
# Connection: keep-alive
# ETag: "5f32b03b-264"
# Accept-Ranges: bytes
```

Pod のログにアクセスできることを確認します。

```sh
kubectl logs $POD_NAME
# 127.0.0.1 - - [22/Sep/2020:17:56:09 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.68.0" "-"
```

Pod 上でコマンドを実行できることを確認します。

```sh
kubectl exec -ti $POD_NAME -- nginx -v
# nginx version: nginx/1.19.2
```

NodePort を通じてアクセスできることを確認します。

```sh
kubectl expose deployment nginx --port 80 --type NodePort
kubectl get svc
# NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
# kubernetes   ClusterIP   10.32.0.1    <none>        443/TCP        44m
# nginx        NodePort    10.32.0.77   <none>        80:32105/TCP   33s

curl -I http://10.0.0.11:32105
# HTTP/1.1 200 OK
# Server: nginx/1.19.2
# Date: Tue, 22 Sep 2020 17:59:16 GMT
# Content-Type: text/html
# Content-Length: 612
# Last-Modified: Tue, 11 Aug 2020 14:50:35 GMT
# Connection: keep-alive
# ETag: "5f32b03b-264"
# Accept-Ranges: bytes

curl -I http://10.0.0.12:32105
# HTTP/1.1 200 OK
# Server: nginx/1.19.2
# Date: Tue, 22 Sep 2020 17:59:20 GMT
# Content-Type: text/html
# Content-Length: 612
# Last-Modified: Tue, 11 Aug 2020 14:50:35 GMT
# Connection: keep-alive
# ETag: "5f32b03b-264"
# Accept-Ranges: bytes

curl -I http://10.0.0.13:32105
# HTTP/1.1 200 OK
# Server: nginx/1.19.2
# Date: Tue, 22 Sep 2020 17:59:24 GMT
# Content-Type: text/html
# Content-Length: 612
# Last-Modified: Tue, 11 Aug 2020 14:50:35 GMT
# Connection: keep-alive
# ETag: "5f32b03b-264"
# Accept-Ranges: bytes
```

## 最後に

Kubernetes を動かすことができましたか？

動かせた方はおめでとうございます。

もしさらに Kubernetes を突き詰めてみたいと思った人は下記のようなことにチャンレンジしてみてください。

- Step Up
  - Master HA
  - 1.19 対応
  - CRI の入れ替え (Docker, cri-o, etc.)
  - CNI Plugin の入れ替え (Flannel, Calico, etc.)
