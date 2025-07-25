# Description

This guide outlines how to set up self-hosted Kubernetes clusters using `kubeadm` within a Docker container based on the `ubuntu:latest` image.
It is designed to create a barebones Kubernetes environment specifically for learning the Kubernetes architecture, experimenting with cluster management, and demonstrating scalability.
We will use `kubeadm` to bootstrap the clusters and `kubectl` to interact with them.

This approach encapsulates the Kubernetes control plane and worker nodes inside Docker containers, providing an isolated and reproducible environment for learning and experimentation.

# Prerequisites

To follow this guide, we will need:

- **Docker installed on our host machine**: Docker will be used to run the container that will host the Kubernetes cluster.
- **Basic understanding of Docker**: Familiarity with running Docker containers and executing commands inside them will be helpful.

# Tools Used in this Guide
- **kubeadm**:  The primary tool for bootstrapping the Kubernetes control plane and worker nodes in a production-like manner.
- **kubectl**: Kubernetes command-line tool to manage the cluster and deploy applications.
- **containerd**: Container runtime for running containers within the Kubernetes nodes.
- **Calico**: Container Network Interface (CNI) for enabling pod networking within the Kubernetes cluster.
- **Ubuntu `latest` Docker Image**: The base operating system for the Docker container hosting the Kubernetes cluster.

## Why?

While tools like `minikube` and `kind` offer simpler and faster ways to set up local Kubernetes clusters, this guide utilizes `kubeadm` for a more hands-on and architecturally representative setup within a Docker container. Here's why this approach is valuable for learning:

*   **Architectural Understanding:** `kubeadm` provides a lower-level approach to cluster setup, mirroring how production Kubernetes clusters are often bootstrapped. By using `kubeadm` inside a Docker container, we gain a deeper understanding of the different Kubernetes components (API server, controller manager, scheduler, kubelet, etc.) and how they are configured and interact, all within an isolated environment.
*   **Production-Like Environment (in a Container):** Clusters created with `kubeadm` more closely resemble production environments compared to those created with those created with `minikube` or `kind`. This includes aspects like certificate management, component configuration, and networking setup, even when contained within Docker.
*   **Customization and Control:** `kubeadm` offers greater flexibility and control over cluster configuration. We can customize various aspects of the cluster to suit specific learning or experimentation needs, and Docker provides a consistent environment to do so.
*   **Preparation for Real-World Deployments:** If our goal is to understand how to deploy and manage Kubernetes in real-world scenarios, learning `kubeadm` is a valuable step. It prepares us for more complex cluster setups and management tasks we might encounter in production environments, and practicing in Docker adds another layer of relevant skills.
*   **kubectl is the Standard:** `kubectl` is the official Kubernetes command-line tool and is universally used to interact with Kubernetes clusters, regardless of how they are set up. Mastering `kubectl` is essential for any Kubernetes user or administrator.
*   **containerd** is chosen because it's a modern, performant, CNCF-graduated, and Kubernetes-native container runtime that strikes a good balance between simplicity and production readiness. It's a solid default choice for Kubernetes and a good runtime to learn with.
*   **calico** is chosen because it's a very feature-rich and widely-used CNI that provides robust pod networking and network policy capabilities. It's a strong choice for production-like environments and learning advanced Kubernetes networking concepts.

In summary, while `kubeadm` involves a more manual and detailed setup process, it is intentionally chosen for this guide to provide a richer learning experience focused on Kubernetes architecture and production-oriented cluster management, now within the controlled and isolated environment of a Docker container. `kubectl` remains the indispensable tool for interacting with and managing any Kubernetes cluster.

# Prepare Server: Docker Container Setup

For this guide, we will set up a single-node Kubernetes cluster inside a Docker container based on the `ubuntu:latest` image. This container will serve as our "server" for deploying Kubernetes.

## Steps to Prepare the Docker Container

1.  **Run a Docker container with Ubuntu base image:** Init the environment container.

    ```bash
    docker run --privileged -it k8s-node /bin/bash                                                                                                                                                                                             
    # docker run --rm -it --privileged --name k8s-node ubuntu:latest /bin/bash
    ```
    *   `docker run`:  This is the Docker command to run a new container.
    *   `--rm`: Automatically removes the container when it exits. This keeps our system clean.
    *   `-it`:  Allocates a pseudo-TTY connected to the container and keeps STDIN open, even if not attached. This allows us to interact with the container's shell.
    *   `--privileged`:  Gives the container extended privileges. **This is necessary for `kubeadm` and Kubernetes components to function correctly inside a Docker container as they need to perform operations that require root capabilities.** Be aware of the security implications of privileged containers, especially in production environments. For learning and isolated experimentation, it is acceptable.
    *   `--name k8s-node`: Assigns the name "k8s-node" to our container, making it easier to reference later.
    *   `ubuntu:latest`: Specifies the Docker image to use as the base for the container. In this case, we are using the latest version of the Ubuntu image.
    *   `/bin/bash`:  Specifies the command to run when the container starts. Here, we are starting a Bash shell, so we can execute commands inside the container.

2.  **We are now inside the Docker container's shell.** All subsequent commands in the following sections (Prepare All Nodes, Install Container Runtime, Install Kubernetes Components, Initialize Kubernetes Control Plane) will be executed **within this Docker container's shell**.

# 1. Prepare All Nodes (Inside the Docker Container)

Perform these steps inside the running Docker container (`k8s-node`).

## Update System
```bash
apt-get update && apt-get upgrade -y
```

## Disable Swap
```bash
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

## Configure Kernel Modules
This step loads kernel modules required by Kubernetes:

*   `overlay`: for container image layering.
*   `br_netfilter`: for bridged networking (CNI like Calico).

These modules are loaded at boot and applied immediately.

```bash
mkdir -p /etc/modules-load.d/
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
```

## Configure Sysctl for Kubernetes Network
```bash
cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
```

# 2. Install Container Runtime (containerd) (Inside the Docker Container)
```bash
# Install dependencies
apt-get install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Docker's official GPG key (for containerd repository - although we are using ubuntu:latest, containerd packages are often from Docker's repo)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg

# Add Docker repository
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
apt-get update
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
systemctl enable containerd
```

# 3. Install Kubernetes Components (Inside the Docker Container)
```bash
# Add Kubernetes repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" # Using xenial repo for compatibility, may need to adjust based on ubuntu:latest version

# Install kubelet, kubeadm, kubectl
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl # Optional: prevent accidental upgrades
```

# 4. Initialize Kubernetes Control Plane (On Control Node - which is our Docker Container) (Inside the Docker Container)
```bash
# Initialize cluster
kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl for current user (root inside container)
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

# 5. Join Worker Nodes (Not applicable for this single-node setup)

This guide focuses on setting up a single-node Kubernetes control plane for learning purposes. Joining worker nodes is not covered in this single-node setup within Docker. For multi-node clusters, consider using VMs or separate Docker containers and adapting the `kubeadm join` command accordingly.

# 6. Verify Cluster (Inside the Docker Container)
```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -A
```

# Post-Installation Recommendations

Once we have our single-node Kubernetes cluster running inside the Docker container, we can explore further Kubernetes concepts and configurations. Consider these next steps:

1.  **Install Helm for package management**:  `helm` is a package manager for Kubernetes, simplifying application deployment and management.
2.  **Set up persistent storage** (e.g., local-path-provisioner):  For stateful applications, we'll need to configure persistent storage.
3.  **Configure network policies**:  Enhance cluster security by defining network policies to control traffic between pods.
4.  **Implement monitoring** (Prometheus, Grafana):  Set up monitoring tools to observe cluster health and application performance.
5.  **Set up logging infrastructure**:  Centralize and manage logs from our Kubernetes cluster and applications.

# Security Considerations

*   **Privileged Container:** Be mindful that this setup uses a `--privileged` Docker container, which has security implications. This is acceptable for a local learning environment but should be carefully considered for more sensitive setups.
*   **Network Policies**: Implement network policies to restrict network traffic within the cluster.
*   **RBAC (Role-Based Access Control)**: Kubernetes RBAC is enabled by default and should be properly configured to control access to cluster resources.
*   **Regularly update Kubernetes and container runtime**: Keep our Kubernetes components and container runtime updated with security patches.
*   **Use pod security admission**: Enforce pod security standards to improve the security posture of our applications.
*   **Implement strict firewall rules**: If exposing our cluster externally, configure firewalls to limit access to necessary ports.
*   **Rotate certificates periodically**: Kubernetes certificates should be rotated regularly for security.

# Troubleshooting

*   **Check `journalctl -u kubelet` for kubelet logs**:  If we encounter issues with Kubernetes components, check the kubelet logs for errors.
*   **Verify container runtime is running**: Ensure `containerd` service is active and running without errors (`systemctl status containerd`).
*   **Ensure all required ports are open (within the container)**: For a single-node setup in Docker, port conflicts are less of an issue, but in more complex setups, ensure necessary ports for Kubernetes components are accessible.
*   **Check network configuration**: Verify that the container's network is configured correctly and that pods can communicate with each other.

---

# Node.js Express App Example

This is a simple Node.js application built with Express. It serves a "Hello, Kubernetes!" message on the root path. It can be deployed on the Kubernetes cluster set up using this guide.

# Prerequisites for Node.js App

* Node.js and npm installed on our machine
* Docker installed (for building and running the container - for the app image, not the k8s cluster)
* kubectl (We will need to install `kubectl` on our **host machine** to interact with the Kubernetes cluster running inside the Docker container.)

# Getting Started with Node.js App

1. **Clone the repository:**

   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```

2. **Build the Docker image for the Node.js app:**

   ```bash
   docker build -t node-app .
   ```

3. **Load the Docker image into the Kubernetes cluster container:**

   Since our Kubernetes cluster is running inside the `k8s-node` Docker container, we need to load the `node-app` image into the *same* Docker environment.  We can do this by copying the image as a tar file and then loading it inside the `k8s-node` container.

   ```bash
   # On our host machine:
   docker save -o node-app.tar node-app:latest
   docker cp node-app.tar k8s-node:/tmp/node-app.tar

   # Inside the k8s-node container:
   docker load -i /tmp/node-app.tar
   ```

4. **Deploy to Kubernetes:**
    * Ensure we are inside the `k8s-node` container and `kubectl` is configured (as done in the guide).
    * Create a deployment and service using the provided Kubernetes configuration files (`k8s/deployment.yaml` and `k8s/service.yaml`).
    * Deploy the application:
      ```bash
      kubectl apply -f k8s/deployment.yaml
      kubectl apply -f k8s/service.yaml
      ```
    * **To access the application from our host machine**, we will need to determine the service's external IP or use port-forwarding since it's a LoadBalancer service in the example. However, in a single-node Docker container setup, LoadBalancer services might not get an external IP in the traditional sense. We might need to use `kubectl port-forward` to access the service on our host machine or change the service type to `NodePort` or `ClusterIP` and adjust access methods accordingly.
    * **Access the application using k9s:** If we have `k9s` installed and configured to connect to our Kubernetes cluster (we'd need to configure `kubectl` context on our host to point to the cluster inside the container, potentially by copying the admin.conf from the container), we can use it to view and manage our deployment. Run `k9s` in our terminal and navigate to the `pods` or `services` view to see our application.
    * **Set the Kubernetes namespace:** If we want to deploy to a specific namespace, set the context:
      ```bash
      kubectl config set-context --current --namespace=<namespace-name>
      ```

# Project Structure

* `main.js`: The main application file (Node.js with Express).
* `package.json`:  Defines the project's dependencies and scripts.
* `Dockerfile`:  Instructions for building the Docker image for the Node.js app.
* `README.md`:  This file.
* `k8s/deployment.yaml`: Kubernetes deployment configuration (example).
* `k8s/service.yaml`: Kubernetes service configuration (example).
* `.dockerignore`:  Specifies files and directories to exclude when building the Docker image.
* `.gitignore`:  Specifies files and directories to exclude from Git version control.

# Isolation

This entire Kubernetes setup is already isolated within a Docker container named `k8s-node`. If we want to further isolate our Node.js application deployments within the Kubernetes cluster, we can use Kubernetes namespaces.

# Inspiring resource

https://github.com/zicodeng/k8s-demo?tab=readme-ov-file

https://github.com/aaliboyev/basic-self-hosted-k8s-cluster/tree/main

# Reference

https://devopscube.com/setup-kubernetes-cluster-kubeadm/#step-7-join-worker-nodes-to-kubernetes-control-plane
