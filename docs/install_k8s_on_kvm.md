# Kubernetes Barebones Demo with KVM, Ubuntu Server, and kubeadm

This guide explains how to build a **realistic, barebones, multi-node Kubernetes cluster** using:

- **KVM/QEMU** virtualization
- **Multiple Ubuntu Server 22.04 LTS VMs**
- **Manual kubeadm setup**
- **Containerd** as the container runtime
- **Calico** as the CNI plugin
- **Node.js demo app** deployed on the cluster
- **JMeter** or similar for scalability/load testing

---

# Why this approach?
- **Closest to production**: no Docker-in-Docker hacks
- **Full control**: learn kubeadm, networking, scaling deeply
- **Barebones**: you bootstrap everything yourself
- **High performance**: KVM + Ubuntu Server + containerd
- **Ubuntu Server preferred**: minimal footprint, no GUI, optimized for server workloads, less overhead than Desktop or Cloud images, making it ideal for lightweight, production-like Kubernetes clusters
- **Multi-node**: realistic cluster behavior
- **Great for demos, learning, experimentation**

---

# Prerequisites

- Linux host with **KVM/QEMU** installed (`virt-manager` recommended)
- Hardware virtualization enabled (VT-x/AMD-V)
- Ubuntu Server 22.04 LTS ISO
- At least **2 VMs** (1 master, 1+ workers), each with:
    - 2+ CPUs
    - 2-4GB RAM
    - 20GB+ disk
- Internet access for package downloads
- Basic Linux skills

---

# Step-by-step setup

## 1. Create Ubuntu Server VMs

- Use `virt-manager` or `virsh` to create 2+ VMs
- Network: **Bridged** or **host-only** so VMs can communicate
- Install Ubuntu Server 22.04 LTS on each VM
- Set static IPs or DHCP reservations for easier access
- Update system:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```

## 2. Prepare all nodes

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl params
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
```

## 3. Install containerd

```bash
sudo apt-get install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y containerd.io
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

## 4. Install Kubernetes components

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## 5. Initialize the control-plane node

On **master node only**:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

Save the `kubeadm join ...` command output.
```text
kubeadm join 192.168.122.211:6443 --token xknpqn.cidcidohojniy5yz \
	--discovery-token-ca-cert-hash sha256:709a96b8ceffe6660379ba432f1daa98332a83b4c93a8c9a2d2c104f0f0d9f97 
```

Configure kubectl:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 6. Install Calico CNI

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

## 7. Join worker nodes

Run the saved `kubeadm join ...` command on each worker node.

## 8. Verify the cluster

```bash
kubectl get nodes
kubectl get pods -A
```
