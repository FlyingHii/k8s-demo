FROM ubuntu:latest
WORKDIR /app

RUN apt-get update && apt-get upgrade -y
RUN sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
CMD ["swapoff", "-a"]

RUN cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
RUN modprobe overlay
RUN modprobe br_netfilter
RUN cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
RUN sysctl --system
