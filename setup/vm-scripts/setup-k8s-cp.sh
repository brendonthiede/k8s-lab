#!/usr/bin/env bash

set -e

# Start kubelet and run kubeadm init
sudo systemctl enable --now kubelet
sudo kubeadm init --control-plane-endpoint "$(hostname -s)" --pod-network-cidr=10.244.0.0/16

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Install etcd tools
ETCD_VERSION="$(kubectl exec -n kube-system etcd-k8s-cp -- etcdctl version | head -n1 | sed 's/.*: //')"
curl -sSL https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
sudo mv -f etcd-v${ETCD_VERSION}*/etcd* /usr/local/bin/
rm -rf etcd-v${ETCD_VERSION}* etcd.tar.gz
