#!/bin/bash

# Initialize cluster
kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl for current user (root inside container)
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Enable and start containerd

containerd > /dev/null 2>&1 &

#systemctl enable containerd
#systemctl start containerd

# Hold kubelet, kubeadm, and kubectl to prevent accidental upgrades
#apt-mark hold kubelet kubeadm kubectl
