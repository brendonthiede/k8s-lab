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