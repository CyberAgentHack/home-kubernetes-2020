#!/bin/bash

ls cert >/dev/null 2>&1
if [[ $? != 0 ]]; then
  echo "Please run in the same directory as cert" 
  exit
fi

mkdir kubeconfig && cd kubeconfig
if [[ $? != 0 ]]; then
  exit
fi

CERT_DIR="../cert"

echo -n "Hostname of Node1: "
read NODE1_HOSTNAME

echo -n "Hostname of Node2: "
read NODE2_HOSTNAME

echo -n "Hostname of Node3: "
read NODE3_HOSTNAME

echo -n "Address of Master Node: "
read MASTER_ADDRESS

echo "---> Generate kubelet kubeconfig"
for instance in k8s1 k8s2 k8s3; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERT_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://${MASTER_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${CERT_DIR}/${instance}.pem \
    --client-key=${CERT_DIR}/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done


echo "---> Generate kube-proxy kubeconfig"
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=${CERT_DIR}/ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=${CERT_DIR}/kube-proxy.pem \
  --client-key=${CERT_DIR}/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig


echo "---> Generate kube-controller-manager kubeconfig"
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=${CERT_DIR}/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=${CERT_DIR}/kube-controller-manager.pem \
  --client-key=${CERT_DIR}/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig


echo "---> Generate kube-scheduler kubeconfig"
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=${CERT_DIR}/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=${CERT_DIR}/kube-scheduler.pem \
  --client-key=${CERT_DIR}/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig


echo "---> Generate admin user kubeconfig"
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=${CERT_DIR}/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=${CERT_DIR}/admin.pem \
  --client-key=${CERT_DIR}/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

echo "---> Complete to generate kubeconfig"
