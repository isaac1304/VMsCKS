# VMsCKS

Infraestructura como código (**Terraform**) para levantar máquinas virtuales de laboratorio en **Google Cloud Platform**, orientadas a la preparación de certificaciones de Kubernetes.

El repositorio tiene **dos laboratorios**, uno por rama. Cada rama es autocontenida: cambiar de laboratorio es cambiar de rama.

| Rama   | Laboratorio | Qué despliega |
|--------|-------------|---------------|
| `main` | **CKS** — Certified Kubernetes Security Specialist | 4 VMs con clúster montado desde cero con `kubeadm` |
| `ICA`  | **ICA** — Istio (service mesh) | 1 VM con clúster Kind + Istio + Bookinfo + observabilidad |

---

## Rama `main` — Laboratorio CKS

Levanta **4 instancias `e2-medium`** (Ubuntu 22.04) en `us-central1-f`, pensadas para practicar la instalación y el hardening de un clúster real:

- **`cks-master`** — nodo maestro; inicializa el control plane con `kubeadm init` e instala la red **Calico**.
- **`cks-master-kubeadm`** — segundo maestro para prácticas con `kubeadm`.
- **`cks-worker`** — nodo worker; incluye binarios de **etcd** (`etcd`/`etcdctl`) para ejercicios de backup/restore.
- **`cks-workerkubeadm`** — worker adicional, también con binarios de etcd.

Cada VM se aprovisiona vía `metadata_startup_script`: instala `containerd`, `kubeadm`, `kubelet`, `kubectl` (v1.28) y aplica la configuración de red de kernel requerida.

---

## Rama `ICA` — Laboratorio Istio

Levanta **1 sola VM `e2-standard-4`** (4 vCPU / 16 GB, mínimo recomendado para Istio) que se autoconfigura por completo al arrancar:

- **`ica-lab`** — instala Docker, `kubectl`, **Kind**, **istioctl** (v1.29) y crea un clúster Kind local.
- Despliega **Istio** (perfil `demo`), la app de ejemplo **Bookinfo** con su Gateway y DestinationRules.
- Instala los addons de observabilidad: **Kiali**, **Prometheus**, **Grafana** y **Jaeger**.

Los puertos 80/443 del gateway quedan expuestos en el host. Al terminar, Terraform imprime **outputs** con la IP pública, el comando SSH y cómo seguir el log de instalación.

---

## Requisitos previos

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- Un proyecto de GCP y una **service account** con permisos sobre Compute Engine.
- El archivo de credenciales `key.json` en la raíz del repo (referenciado por `provider.tf`).

> ⚠️ `key.json` contiene credenciales sensibles y **no debe subirse al repositorio**. Verifica que esté en `.gitignore`.

## Uso

```bash
# 1. Selecciona el laboratorio que quieres levantar
git checkout main    # laboratorio CKS
#   ó
git checkout ICA     # laboratorio Istio

# 2. Inicializa Terraform (descarga el provider de Google)
terraform init

# 3. Revisa qué se va a crear
terraform plan

# 4. Crea la infraestructura
terraform apply

# 5. Al terminar, destruye para no seguir facturando
terraform destroy
```

En la rama `ICA`, tras el `apply` puedes conectarte con el comando SSH que aparece en los outputs y seguir el aprovisionamiento con:

```bash
tail -f /var/log/ica-startup.log
```

## Estructura

```
├── main.tf              # Definición de las VMs (difiere según la rama)
├── provider.tf          # Configuración del provider de Google
├── key.json             # Credenciales de la service account (NO versionar)
└── terraform.tfstate    # Estado de Terraform
```
