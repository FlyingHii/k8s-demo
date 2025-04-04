FROM ubuntu:latest // ai! use ubuntu 22
WORKDIR /app

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y kmod
RUN sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
CMD ["swapoff", "-a"]

RUN mkdir -p /etc/modules-load.d/
RUN cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
RUN modprobe overlay
RUN modprobe br_netfilter
RUN lsmod | grep overlay || (echo "Error: overlay module not loaded" && exit 1)
RUN lsmod | grep br_netfilter || (echo "Error: br_netfilter module not loaded" && exit 1)
RUN cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
RUN sysctl --system
