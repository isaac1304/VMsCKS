resource "google_compute_instance" "ica-lab" {
  name         = "ica-lab"
  machine_type = "e2-standard-4"   # 4 vCPU / 16 GB RAM — mínimo recomendado para Istio
  zone         = "us-central1-f"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250112"
      size  = "50"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "root:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCx8yJnQoIW1XVwJFj3E59XjYg/KR2TPllJ4nKbHkLnRKITXyr+myC13uTiyq0qKHvhDY+QsEgR1U/1/xZo6FThUgnnnW0vgaaf3fRpEiRwVHMgzoLPuI7bBrG9FwwdGZMTDc3z0gft58Bs9Mu5W4IgNDgID85hXHb7Vkmwg+/e3yJO5N2TpizccFWrMw8Fmh2wIL/jRYmrtxQ8f7WzqsAFpAO0VZvwyKDTy+j92JYwdw8y225RA9o13gMGwyYSCXzugatAk0KoA9++IjvjcVE9R73sgNS97r17c5QPIjxwqXIZqJdOZlr6jB/nK4m9Ou1TZkjslGUYunX6Imu81g4f1FWqj6ZO6obRL4MmcqvqxOcBqSm2KrRnko1fYFiqRuvsc1HnjAdz8ZED/nZu9X/oJKpJbazmFyDy7h5trIj0akWGjrMdH98Q+wN3ic/tw+k5dMS5mKEvJrCBMmkim+ml7oz9ffuIMBh7vdIl76+Hj8V1mLM4dbGNzBxlPJaHpx44H6K1xihdR8HOV22sTHk/ixpFWFG5L8AZvyW6yQXXjA8hSu0h9IPoFQgHsin2l0ARDL96BR6Yw6AKpNvA8Iu7la3J/OyRx47qVU/mElJMiEhOzKTpT8X0mtyJd4fTgkmFtjwmZPc+IZcQ2Wjzgds4dYChPiAf7l0oESyWo6erw== root"
  }

  metadata_startup_script = <<EOT
#!/bin/bash
exec > /var/log/ica-startup.log 2>&1
set -e

echo "===== [1/6] Instalando dependencias base ====="
apt-get update && apt-get install -y \
  curl wget apt-transport-https ca-certificates \
  gnupg lsb-release git jq

echo "===== [2/6] Instalando Docker ====="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker && systemctl start docker

echo "===== [3/6] Instalando kubectl ====="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update && apt-get install -y kubectl
kubectl completion bash > /etc/bash_completion.d/kubectl
echo "alias k=kubectl" >> /root/.bashrc
echo "complete -o default -F __start_kubectl k" >> /root/.bashrc

echo "===== [4/6] Instalando Kind ====="
KIND_VERSION="v0.23.0"
curl -Lo /usr/local/bin/kind \
  https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
chmod +x /usr/local/bin/kind

echo "===== [5/6] Instalando istioctl v1.29 ====="
ISTIO_VERSION="1.29.0"
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=x86_64 sh -
mv /root/istio-${ISTIO_VERSION}/bin/istioctl /usr/local/bin/istioctl
chmod +x /usr/local/bin/istioctl
istioctl completion bash > /etc/bash_completion.d/istioctl

echo "===== [6/6] Creando cluster Kind + desplegando Istio + Bookinfo ====="

# Configuración del cluster con puertos expuestos para el ingress gateway
cat <<EOF > /root/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-lab
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 80
    protocol: TCP
  - containerPort: 30001
    hostPort: 443
    protocol: TCP
EOF

kind create cluster --config /root/kind-config.yaml
export KUBECONFIG=/root/.kube/config

# Esperar a que el nodo esté listo
kubectl wait --for=condition=Ready node/istio-lab-control-plane --timeout=120s

# Instalar Istio con perfil demo
istioctl install --set profile=demo -y

# Habilitar sidecar injection en el namespace default
kubectl label namespace default istio-injection=enabled

# Desplegar Bookinfo
ISTIO_PATH="/root/istio-${ISTIO_VERSION}"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/networking/bookinfo-gateway.yaml

# Desplegar addons de observabilidad (Kiali, Prometheus, Grafana, Jaeger)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/kiali.yaml

# Esperar a que Bookinfo esté listo
kubectl wait --for=condition=Ready pods --all -n default --timeout=180s

# DestinationRules base para Bookinfo (necesarias para los ejercicios de routing)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/networking/destination-rule-all.yaml

# Persistir KUBECONFIG en .bashrc
echo "export KUBECONFIG=/root/.kube/config" >> /root/.bashrc
echo "source /etc/bash_completion.d/kubectl" >> /root/.bashrc
echo "source /etc/bash_completion.d/istioctl" >> /root/.bashrc

echo ""
echo "======================================================"
echo " ICA Lab listo! Estado del cluster:"
echo "======================================================"
kubectl get pods -A
echo ""
echo " Verifica el log completo en: /var/log/ica-startup.log"
echo "======================================================"
EOT

  service_account {
    email  = "cks-testvms@tidy-simplicity-359100.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

output "ica_lab_ip" {
  description = "IP pública de la VM de práctica ICA"
  value       = google_compute_instance.ica-lab.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "Comando para conectarse a la VM"
  value       = "ssh root@${google_compute_instance.ica-lab.network_interface[0].access_config[0].nat_ip}"
}

output "check_setup_log" {
  description = "Comando para verificar el progreso del setup"
  value       = "ssh root@${google_compute_instance.ica-lab.network_interface[0].access_config[0].nat_ip} 'tail -f /var/log/ica-startup.log'"
}