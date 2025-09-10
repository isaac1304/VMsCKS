resource "google_compute_instance" "cks-master" {
  name         = "cks-master"
  machine_type = "e2-medium"
  zone         = "us-central1-f"

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250112"
      size  = "50"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    foo      = "bar"
    ssh-keys = "root:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCx8yJnQoIW1XVwJFj3E59XjYg/KR2TPllJ4nKbHkLnRKITXyr+myC13uTiyq0qKHvhDY+QsEgR1U/1/xZo6FThUgnnnW0vgaaf3fRpEiRwVHMgzoLPuI7bBrG9FwwdGZMTDc3z0gft58Bs9Mu5W4IgNDgID85hXHb7Vkmwg+/e3yJO5N2TpizccFWrMw8Fmh2wIL/jRYmrtxQ8f7WzqsAFpAO0VZvwyKDTy+j92JYwdw8y225RA9o13gMGwyYSCXzugatAk0KoA9++IjvjcVE9R73sgNS97r17c5QPIjxwqXIZqJdOZlr6jB/nK4m9Ou1TZkjslGUYunX6Imu81g4f1FWqj6ZO6obRL4MmcqvqxOcBqSm2KrRnko1fYFiqRuvsc1HnjAdz8ZED/nZu9X/oJKpJbazmFyDy7h5trIj0akWGjrMdH98Q+wN3ic/tw+k5dMS5mKEvJrCBMmkim+ml7oz9ffuIMBh7vdIl76+Hj8V1mLM4dbGNzBxlPJaHpx44H6K1xihdR8HOV22sTHk/ixpFWFG5L8AZvyW6yQXXjA8hSu0h9IPoFQgHsin2l0ARDL96BR6Yw6AKpNvA8Iu7la3J/OyRx47qVU/mElJMiEhOzKTpT8X0mtyJd4fTgkmFtjwmZPc+IZcQ2Wjzgds4dYChPiAf7l0oESyWo6erw== root"
  }

metadata_startup_script = <<EOT
#!/bin/bash
# Redirigir la salida a un archivo de log
exec > /var/log/startup-script.log 2>&1

# Paso 0: Actualizar e instalar dependencias básicas
apt-get update && apt-get install -y wget apt-transport-https ca-certificates curl gpg

# Paso 1: Configurar el repositorio de Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update

# Paso 2: Instalar kubeadm, kubelet, kubectl y cri-tools
apt-get install -y kubeadm kubelet kubectl cri-tools
apt-mark hold kubeadm kubelet kubectl

# Paso 3: Configurar containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Paso 4: Inicializar Kubernetes (solo en nodo maestro)
if [ "$(hostname)" == "cks-master" ]; then
  kubeadm init --pod-network-cidr=192.168.0.0/16
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
fi
EOT

  service_account {
    email  = "cks-testvms@tidy-simplicity-359100.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "cks-master-kubeadm" {
  name         = "cks-master-kubeadm"
  machine_type = "e2-medium"
  zone         = "us-central1-f"

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250112"
      size  = "50"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    foo      = "bar"
    ssh-keys = "root:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCx8yJnQoIW1XVwJFj3E59XjYg/KR2TPllJ4nKbHkLnRKITXyr+myC13uTiyq0qKHvhDY+QsEgR1U/1/xZo6FThUgnnnW0vgaaf3fRpEiRwVHMgzoLPuI7bBrG9FwwdGZMTDc3z0gft58Bs9Mu5W4IgNDgID85hXHb7Vkmwg+/e3yJO5N2TpizccFWrMw8Fmh2wIL/jRYmrtxQ8f7WzqsAFpAO0VZvwyKDTy+j92JYwdw8y225RA9o13gMGwyYSCXzugatAk0KoA9++IjvjcVE9R73sgNS97r17c5QPIjxwqXIZqJdOZlr6jB/nK4m9Ou1TZkjslGUYunX6Imu81g4f1FWqj6ZO6obRL4MmcqvqxOcBqSm2KrRnko1fYFiqRuvsc1HnjAdz8ZED/nZu9X/oJKpJbazmFyDy7h5trIj0akWGjrMdH98Q+wN3ic/tw+k5dMS5mKEvJrCBMmkim+ml7oz9ffuIMBh7vdIl76+Hj8V1mLM4dbGNzBxlPJaHpx44H6K1xihdR8HOV22sTHk/ixpFWFG5L8AZvyW6yQXXjA8hSu0h9IPoFQgHsin2l0ARDL96BR6Yw6AKpNvA8Iu7la3J/OyRx47qVU/mElJMiEhOzKTpT8X0mtyJd4fTgkmFtjwmZPc+IZcQ2Wjzgds4dYChPiAf7l0oESyWo6erw== root"
  }

metadata_startup_script = <<EOT
#!/bin/bash
# Redirigir la salida a un archivo de log
exec > /var/log/startup-script.log 2>&1

# Paso 0: Actualizar e instalar dependencias básicas
apt-get update && apt-get install -y wget apt-transport-https ca-certificates curl gpg

# Paso 1: Configurar el repositorio de Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update

# Paso 2: Instalar kubeadm, kubelet, kubectl y cri-tools
apt-get install -y kubeadm kubelet kubectl cri-tools
apt-mark hold kubeadm kubelet kubectl

# Paso 3: Configurar containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Paso 4: Inicializar Kubernetes (solo en nodo maestro)
if [ "$(hostname)" == "cks-master" ]; then
  kubeadm init --pod-network-cidr=192.168.0.0/16
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
fi
EOT

  service_account {
    email  = "cks-testvms@tidy-simplicity-359100.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "cks-worker" {
  name         = "cks-worker"
  machine_type = "e2-medium"
  zone         = "us-central1-f"

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250112"
      size  = "50"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    foo      = "bar"
    ssh-keys = "root:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCx8yJnQoIW1XVwJFj3E59XjYg/KR2TPllJ4nKbHkLnRKITXyr+myC13uTiyq0qKHvhDY+QsEgR1U/1/xZo6FThUgnnnW0vgaaf3fRpEiRwVHMgzoLPuI7bBrG9FwwdGZMTDc3z0gft58Bs9Mu5W4IgNDgID85hXHb7Vkmwg+/e3yJO5N2TpizccFWrMw8Fmh2wIL/jRYmrtxQ8f7WzqsAFpAO0VZvwyKDTy+j92JYwdw8y225RA9o13gMGwyYSCXzugatAk0KoA9++IjvjcVE9R73sgNS97r17c5QPIjxwqXIZqJdOZlr6jB/nK4m9Ou1TZkjslGUYunX6Imu81g4f1FWqj6ZO6obRL4MmcqvqxOcBqSm2KrRnko1fYFiqRuvsc1HnjAdz8ZED/nZu9X/oJKpJbazmFyDy7h5trIj0akWGjrMdH98Q+wN3ic/tw+k5dMS5mKEvJrCBMmkim+ml7oz9ffuIMBh7vdIl76+Hj8V1mLM4dbGNzBxlPJaHpx44H6K1xihdR8HOV22sTHk/ixpFWFG5L8AZvyW6yQXXjA8hSu0h9IPoFQgHsin2l0ARDL96BR6Yw6AKpNvA8Iu7la3J/OyRx47qVU/mElJMiEhOzKTpT8X0mtyJd4fTgkmFtjwmZPc+IZcQ2Wjzgds4dYChPiAf7l0oESyWo6erw== root"
  }

  metadata_startup_script = <<EOT
#!/bin/bash
# Paso 0: Instalar wget y paquetes necesarios
apt-get update && apt-get -y install wget

# Paso 1: Crear directorio para binarios de ETCD
mkdir -p /root/binaries
cd /root/binaries

# Paso 2: Descargar y extraer binarios de ETCD
wget https://github.com/etcd-io/etcd/releases/download/v3.5.4/etcd-v3.5.4-linux-amd64.tar.gz
tar -zxvf etcd-v3.5.4-linux-amd64.tar.gz
cd etcd-v3.5.4-linux-amd64
cp etcd etcdctl /usr/local/bin/
EOT

  service_account {
    email  = "cks-testvms@tidy-simplicity-359100.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "cks-worke-kubeadm" {
  name         = "cks-workerkubeadm"
  machine_type = "e2-medium"
  zone         = "us-central1-f"

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250112"
      size  = "50"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    foo      = "bar"
    ssh-keys = "root:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCx8yJnQoIW1XVwJFj3E59XjYg/KR2TPllJ4nKbHkLnRKITXyr+myC13uTiyq0qKHvhDY+QsEgR1U/1/xZo6FThUgnnnW0vgaaf3fRpEiRwVHMgzoLPuI7bBrG9FwwdGZMTDc3z0gft58Bs9Mu5W4IgNDgID85hXHb7Vkmwg+/e3yJO5N2TpizccFWrMw8Fmh2wIL/jRYmrtxQ8f7WzqsAFpAO0VZvwyKDTy+j92JYwdw8y225RA9o13gMGwyYSCXzugatAk0KoA9++IjvjcVE9R73sgNS97r17c5QPIjxwqXIZqJdOZlr6jB/nK4m9Ou1TZkjslGUYunX6Imu81g4f1FWqj6ZO6obRL4MmcqvqxOcBqSm2KrRnko1fYFiqRuvsc1HnjAdz8ZED/nZu9X/oJKpJbazmFyDy7h5trIj0akWGjrMdH98Q+wN3ic/tw+k5dMS5mKEvJrCBMmkim+ml7oz9ffuIMBh7vdIl76+Hj8V1mLM4dbGNzBxlPJaHpx44H6K1xihdR8HOV22sTHk/ixpFWFG5L8AZvyW6yQXXjA8hSu0h9IPoFQgHsin2l0ARDL96BR6Yw6AKpNvA8Iu7la3J/OyRx47qVU/mElJMiEhOzKTpT8X0mtyJd4fTgkmFtjwmZPc+IZcQ2Wjzgds4dYChPiAf7l0oESyWo6erw== root"
  }

  metadata_startup_script = <<EOT
#!/bin/bash
# Paso 0: Instalar wget y paquetes necesarios
apt-get update && apt-get -y install wget

# Paso 1: Crear directorio para binarios de ETCD
mkdir -p /root/binaries
cd /root/binaries

# Paso 2: Descargar y extraer binarios de ETCD
wget https://github.com/etcd-io/etcd/releases/download/v3.5.4/etcd-v3.5.4-linux-amd64.tar.gz
tar -zxvf etcd-v3.5.4-linux-amd64.tar.gz
cd etcd-v3.5.4-linux-amd64
cp etcd etcdctl /usr/local/bin/
EOT

  service_account {
    email  = "cks-testvms@tidy-simplicity-359100.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}