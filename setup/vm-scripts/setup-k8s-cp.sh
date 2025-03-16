#!/usr/bin/env bash

EXTRA_SANS=$1

# Start kubelet and run kubeadm init
sudo systemctl enable --now kubelet
if [ -n "$EXTRA_SANS" ]; then
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans "$EXTRA_SANS"
else
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
fi

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml