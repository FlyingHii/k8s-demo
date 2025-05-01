# Gin Gonic Demo App Deployment on a Barebones Kubernetes Cluster

This guide explains how to build and deploy a simple Gin Gonic demo application onto a barebones, multi-node Kubernetes cluster that has been set up using the [Kubernetes Barebones Demo with KVM, Ubuntu Server, and kubeadm guide](docs/install_k8s_on_kvm.md).

---

# Prerequisites

- A running Kubernetes cluster set up according to the [Kubernetes Barebones Demo with KVM, Ubuntu Server, and kubeadm guide](docs/install_k8s_on_kvm.md).
- `kubectl` configured on your host machine to interact with the cluster (usually done on the master node as per the setup guide).
- Docker installed on your host machine (to build the app image).
- Go installed on your host machine (to manage Go dependencies and potentially test locally).
- Access to the cluster nodes (e.g., via SSH) if you plan to manually load the Docker image instead of using a registry.
- The Gin Gonic application source code (`src/main.go`) and Go module file (`go.mod`) in the repository.
- A `Dockerfile` for the Gin Gonic application in the root directory.

---

# Deploy the Gin Gonic demo app

1. **Build the Docker image**

```bash
# Ensure you are in the root directory of the project
docker build -t go-app .
```
*(We are reusing the image tag `go-app:latest` for simplicity, as referenced in `k8s/deployment.yaml`)*

2. **Load the image into your cluster nodes**

- Push to a registry **or**
- Save the image as a tar file and copy it to each worker node, then load it:
  ```bash
  docker save -o go-app.tar go-app:latest
  scp go-app.tar user@worker:/tmp/
  ssh user@worker 'docker load -i /tmp/go-app.tar'
  ```
  *(Replace `user` and `worker` with your actual username and worker node hostname/IP)*
3. **Deploy to Kubernetes**

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

4. **Access the app**

- Use `kubectl port-forward` or NodePort service
- If using a LoadBalancer service, you might need a cloud provider integration or a tool like MetalLB in a baremetal/VM setup to get an external IP. Alternatively, use `NodePort` or `ClusterIP` and access methods suitable for your environment.
- Or configure Ingress

---

# Load testing and scalability demo

- Use **JMeter**, **wrk**, or **hey** to generate load
- Scale up/down:
  ```bash
  kubectl scale deployment my-app-deployment --replicas=5
  ```
- Observe pod scheduling, resource usage, resilience

---

# Summary

- KVM + Ubuntu Server 22.04 LTS VMs
- Manual kubeadm + containerd + Calico
- Multi-node, barebones, production-like
- Gin Gonic app deployed via Kubernetes
- Load testing with JMeter or similar

---

# Why this is a great demo

- Full control, transparency
- Realistic architecture
- Learn kubeadm, networking, scaling deeply
- No Docker-in-Docker hacks
- High performance
- Perfect for education, experimentation, and showcasing Kubernetes
