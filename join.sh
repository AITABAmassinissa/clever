sudo iptables -P FORWARD ACCEPT

sudo swapoff -a

sudo ufw disable #NOT RECOMMENDED in PROD

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sudo apt update
sudo apt install -y curl ca-certificates apt-transport-https containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm
sudo apt install -y kubectl  # ONLY FOR MASTER



sudo kubeadm reset -f 2>/dev/null; sudo systemctl stop kubelet 2>/dev/null; sudo apt-mark unhold kubelet kubeadm kubectl 2>/dev/null; sudo apt-get purge -y kubelet kubeadm kubectl kubernetes-cni; sudo apt-get autoremove -y; sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/cni /opt/cni /var/lib/cni /var/lib/dockershim ~/.kube /etc/apt/sources.list.d/kubernetes.list /etc/apt/keyrings/kubernetes-apt-keyring.gpg; sudo apt-get update; sudo apt-get install -y apt-transport-https ca-certificates curl gpg; sudo mkdir -p -m 755 /etc/apt/keyrings; curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; sudo apt-get update; sudo apt-get install -y kubelet kubeadm kubectl; sudo apt-mark hold kubelet kubeadm kubectl; kubectl version --client

# --- Clean ---
sudo sysctl net.ipv4.conf.all.forwarding=1
sudo iptables -P FORWARD ACCEPT
sudo swapoff -a
sudo ufw disable
sudo ufw status
sudo ip link delete flannel.1 2>/dev/null
sudo ip link delete cni0 2>/dev/null
rm -f $HOME/.kube/config
sudo kubeadm reset -f

# --- Install Docker (docs.docker.com/engine/install/ubuntu) ---
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- Kernel modules & sysctl ---
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# --- Init cluster ---
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# --- Configure kubectl ---
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# --- Flannel CNI ---
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# --- Allow scheduling on control-plane (single-node) ---
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# --- Multus CNI (applied directly from repo, no local download) ---
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml