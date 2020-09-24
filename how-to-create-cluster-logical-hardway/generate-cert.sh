#!/bin/bash

mkdir cert && cd cert
if [[ $? != 0 ]]; then
  exit
fi

echo -n "Hostname of Node1: "
read NODE1_HOSTNAME

echo -n "Hostname of Node2: "
read NODE2_HOSTNAME

echo -n "Hostname of Node3: "
read NODE3_HOSTNAME

echo -n "Addresses of Node1 (x.x.x.x[,x.x.x.x]): "
read NODE1_ADDRESS

echo -n "Addresses of Node2 (x.x.x.x[,x.x.x.x]): "
read NODE2_ADDRESS

echo -n "Addresses of Node3 (x.x.x.x[,x.x.x.x]): "
read NODE3_ADDRESS

echo -n "Address of Kubernetes ClusterIP (first address of ClusterIP subnet): "
read KUBERNETES_SVC_ADDRESS

# echo ${NODE1_HOSTNAME}
# echo ${NODE2_HOSTNAME}
# echo ${NODE3_HOSTNAME}
# echo ${NODE1_ADDRESS}
# echo ${NODE2_ADDRESS}
# echo ${NODE3_ADDRESS}
# echo ${KUBERNETES_SVC_ADDRESS}

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate CA certificate"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca


cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate certificate for admin user"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin


for instance in ${NODE1_HOSTNAME} ${NODE2_HOSTNAME} ${NODE3_HOSTNAME}; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF
done

echo "---> Generate certificate for kubelet"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${NODE1_HOSTNAME},${NODE1_ADDRESS} \
  -profile=kubernetes \
  ${NODE1_HOSTNAME}-csr.json | cfssljson -bare ${NODE1_HOSTNAME}
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${NODE2_HOSTNAME},${NODE2_ADDRESS} \
  -profile=kubernetes \
  ${NODE2_HOSTNAME}-csr.json | cfssljson -bare ${NODE2_HOSTNAME}
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${NODE3_HOSTNAME},${NODE3_ADDRESS} \
  -profile=kubernetes \
  ${NODE3_HOSTNAME}-csr.json | cfssljson -bare ${NODE3_HOSTNAME}


cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate certificate for kube-controller-manager"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager


cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate certificate for kube-proxy"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy


cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate certificate for kube-scheduler"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler


KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate certificate for kube-api-server"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${KUBERNETES_SVC_ADDRESS},${NODE1_ADDRESS},${NODE2_ADDRESS},${NODE3_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes


cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "JP",
      "L": "Setagaya",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Tokyo"
    }
  ]
}
EOF

echo "---> Generate certificate for generating token of ServiceAccount"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account


echo "---> Complete to generate certificate"
