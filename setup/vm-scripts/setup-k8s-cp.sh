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

# Fix etcd to not use the dynamic IP address (this will knock the cluster out for a bit)
sudo sed -i \
    -e 's|\-\-listen-peer-urls=.*|--listen-peer-urls=https://127.0.0.1:2380|' \
    -e 's|\-\-listen-client-urls=.*|--listen-client-urls=https://127.0.0.1:2379|' \
    -e 's|\-\-initial-advertise-peer-urls=.*|--initial-advertise-peer-urls=https://127.0.0.1:2380|' \
    -e 's|\-\-initial-cluster=k8s-cp=.*|--initial-cluster=k8s-cp=https://127.0.0.1:2379|' \
    -e 's|\-\-advertise-client-urls=.*|--advertise-client-urls=https://127.0.0.1:2380|' \
    /etc/kubernetes/manifests/etcd.yaml

# Give access to crictl
sudo groupadd containerd
sudo usermod -aG containerd $USER
sudo chown root:containerd /run/containerd/containerd.sock
sudo chmod 660 /run/containerd/containerd.sock
sudo chown -R root:containerd /var/log/containers
sudo chmod g+s /var/log/containers
sudo chown -R root:containerd /var/log/pods
sudo chmod g+s /var/log/pods

# Install etcd tools
ETCD_VERSION="$(sudo cat /etc/kubernetes/manifests/etcd.yaml | grep image: | sed -e 's|.*/etcd:||' -e 's|\-.*||')"
curl -sSL https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
sudo mv -f etcd-v${ETCD_VERSION}*/etcd* /usr/local/bin/
rm -rf etcd-v${ETCD_VERSION}* etcd.tar.gz
