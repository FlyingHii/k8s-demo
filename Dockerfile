FROM ubuntu:22.04
WORKDIR /app

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y kmod

# Install extra kernel modules to include overlay and br_netfilter
RUN apt-get install -y linux-modules-extra-$(uname -r)

RUN sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

RUN mkdir -p /etc/modules-load.d/
RUN cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
RUN modprobe overlay

RUN lsmod | grep overlay || (echo "Error: overlay module not loaded" && exit 1)

#RUN modprobe br_netfilter
#RUN modprobe --security=insecure br_netfilter
#RUN --security=insecure modprobe br_netfilter
#RUN modprobe --security=CAP_ADD:SYS_MODULE br_netfilter
#RUN lsmod | grep br_netfilter || (echo "Error: br_netfilter module not loaded" && exit 1)

RUN cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
RUN sysctl --system

# Install Container Runtime (containerd) (Inside the Docker Container)
RUN apt-get install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg

RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

RUN apt-get update
RUN apt-get install -y containerd.io

RUN mkdir -p /etc/containerd
RUN containerd config default | tee /etc/containerd/config.toml

RUN sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

RUN systemctl enable containerd

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update and install prerequisites
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Add Kubernetes GPG key
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes apt repository (using the new URL format)
RUN echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
RUN apt-get update && apt-get install -y \
    kubelet \
    kubeadm \
    kubectl \
    && apt-mark hold kubelet kubeadm kubectl \
    && rm -rf /var/lib/apt/lists/*

CMD ["swapoff", "-a"]
