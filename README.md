# Self-Hosted Kubernetes (k8s) Cluster Setup Guide

## Prerequisites
- Linux machines (Ubuntu 22.04 LTS recommended)
- Minimum 3 nodes (1 control plane, 2 worker nodes)
- Each node requirements:
   - 2 CPU cores
   - 4GB RAM
   - 20GB disk space
   - Static IP addresses
   - Disabled swap
   - Unique hostname

## 1. Prepare All Nodes

### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Disable Swap
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### Configure Kernel Modules
```bash
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### Configure Sysctl for Kubernetes Network
```bash
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

## 2. Install Container Runtime (containerd)
```bash
# Install dependencies
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg

# Add Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
sudo apt update
sudo apt install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
```

## 3. Install Kubernetes Components
```bash
# Add Kubernetes repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

# Install kubelet, kubeadm, kubectl
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## 4. Initialize Kubernetes Control Plane (On Control Node)
```bash
# Initialize cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl for current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

## 5. Join Worker Nodes
On each worker node, run the join command generated during control plane initialization:
```bash
sudo kubeadm join <control-plane-host>:<control-plane-port> \
  --token <token> \
  --discovery-token-ca-cert-hash <hash>
```

## 6. Verify Cluster
```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -A
```

## Post-Installation Recommendations
1. Install Helm for package management
2. Set up persistent storage (e.g., local-path-provisioner)
3. Configure network policies
4. Implement monitoring (Prometheus, Grafana)
5. Set up logging infrastructure

## Security Considerations
- Use network policies
- Enable RBAC
- Regularly update Kubernetes and container runtime
- Use pod security admission
- Implement strict firewall rules
- Rotate certificates periodically

## Troubleshooting
- Check `journalctl -u kubelet` for kubelet logs
- Verify container runtime is running
- Ensure all required ports are open
- Check network configuration

---

## Node.js Express App Example

This is a simple Node.js application built with Express. It serves a "Hello, Kubernetes!" message on the root path. It can be deployed on the Kubernetes cluster set up using this guide.

## Prerequisites for Node.js App

* Node.js and npm installed on your machine
* Docker installed (for building and running the container)
* kubectl (for deploying to Kubernetes, if applicable)

## Getting Started with Node.js App

1. **Clone the repository:**

   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```

2. **Build the Docker image:**

   ```bash
   docker build -t node-app .
   ```

3. **Run the Docker container:**

   ```bash
   docker run -p 8080:8080 node-app
   ```

   This will start the application and make it accessible on `http://localhost:8080`.

4. **(Optional) Deploy to Kubernetes:**
    * Ensure you have a Kubernetes cluster running and `kubectl` configured to connect to it. You can use the cluster you set up using the guide above, or tools like Minikube or Docker Desktop (which includes a Kubernetes cluster). Start Minikube with `minikube start` or ensure Kubernetes is enabled in Docker Desktop settings.
    * Create a deployment and service using the provided Kubernetes configuration files (`k8s/deployment.yaml` and `k8s/service.yaml`).
    * Deploy the application:
      ```bash
      kubectl apply -f k8s/deployment.yaml
      kubectl apply -f k8s/service.yaml
      ```
    * Access the application through the service's external IP or hostname.
    * **Access the application using k9s:** If you have `k9s` installed and configured to connect to your Kubernetes cluster, you can use it to view and manage your deployment. Run `k9s` in your terminal and navigate to the `pods` or `services` view to see your application.
    * **Set the Kubernetes namespace:** If you want to deploy to a specific namespace, set the context:
      ```bash
      kubectl config set-context --current --namespace=<namespace-name>
      ```

## Project Structure

* `main.js`: The main application file (Node.js with Express).
* `package.json`:  Defines the project's dependencies and scripts.
* `Dockerfile`:  Instructions for building the Docker image.
* `README.md`:  This file.
* `k8s/deployment.yaml`: Kubernetes deployment configuration (example).
* `k8s/service.yaml`: Kubernetes service configuration (example).
* `.dockerignore`:  Specifies files and directories to exclude when building the Docker image.
* `.gitignore`:  Specifies files and directories to exclude from Git version control.
