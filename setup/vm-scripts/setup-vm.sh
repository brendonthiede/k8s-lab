#!/usr/bin/env bash

# Update the apt package index and install packages needed to configure the k8s apt repo
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Install the root CA certificates
sudo mkdir -p /usr/local/share/ca-certificates
sudo cp /home/ubuntu/setup/root-cas/*.crt /usr/local/share/ca-certificates/
sudo chmod 644 /usr/local/share/ca-certificates/*.crt
sudo update-ca-certificates

# Configure the apt repo for Kubernetes
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubelet, kubeadm, kubectl, and containerd
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl containerd
sudo apt-mark hold kubeadm kubelet kubectl

# Configure command completion for kubectl
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Disable swap (kubeadm init will fail if swap is enabled)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load necessary kernel modules for Kubernetes networking
sudo modprobe overlay
sudo modprobe br_netfilter
echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

# Configure sysctl settings for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Reboot the VM
if [ -f /var/run/reboot-required ]; then
    cat /var/run/reboot-required
    sudo reboot
fi
