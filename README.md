# infra — Plateforme AWS EKS avec Terraform

Infrastructure AWS de production montée et détruite à la demande, écrite entièrement en Terraform avec des modules maison (sans module communautaire)

## Avancement

- [x] Backend du state Terraform (S3 versionné, chiffré, verrouillage natif)
- [x] Réseau multi-AZ : VPC, subnets publics et privés sur 3 AZ, Internet Gateway, NAT Gateway
- [x] Bastion EC2 configuré par cloud-init, accès SSH restreint
- [x] Control plane EKS (rôle IAM, endpoint public restreint + privé)
- [ ] Nœuds EKS (managed node group)
- [ ] Accès `kubectl` depuis le bastion (rôle IAM, access entry EKS)
- [ ] Base PostgreSQL (RDS) et registre d'images (ECR)
- [ ] Configuration du bastion avec Ansible (Jenkins, outils)
- [ ] Déploiement GitOps avec ArgoCD
- [ ] Monitoring (Prometheus, Grafana)
- [ ] Accès au bastion via Tailscale, port 22 fermé

## Architecture

```
                          Internet
                             │
┌─ Région eu-west-3 ─────────┼──────────────────────────────────────────┐
│ ┌─ VPC 10.0.0.0/16 ────────┼───────────────────────────────────────┐  │
│ │                          │                                       │  │
│ │  Subnets publics    Internet Gateway                             │  │
│ │  10.0.0-2.0/24           │                                       │  │
│ │   ├── Bastion EC2  ◄── SSH (IP admin uniquement)                 │  │
│ │   └── NAT Gateway                                                │  │
│ │          │                                                       │  │
│ │  Subnets privés                                                  │  │
│ │  10.0.3-5.0/24                                                   │  │
│ │   └── EKS (interfaces du control plane, nœuds à venir)           │  │
│ │                                                                  │  │
│ └──────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  Control plane EKS (géré par AWS)    S3 : state Terraform             │
└───────────────────────────────────────────────────────────────────────┘
```

Chaque AZ (`eu-west-3a`, `b`, `c`) possède un subnet public et un subnet privé. Les subnets privés sortent sur Internet par le NAT Gateway.

## Structure du dépôt

```
terraform/
├── environnements/
│   ├── backend_s3/      # bucket du state, créé une seule fois
│   └── prod/            # assemble les modules, un state par environnement
└── modules/
    ├── backend/         # bucket S3 du state
    ├── network/         # VPC, subnets, routes, IGW, NAT
    ├── security/        # security groups
    ├── compute/         # instance bastion + cloud-init
    └── eks/             # cluster EKS et son rôle IAM
ansible/                 # à venir
gitops/                  # à venir
```

Chaque environnement est un dossier qui appelle les modules et se configure par son propre `terraform.tfvars`. Ajouter un environnement `dev` consiste à copier le dossier `prod` et à changer ses variables.

## Choix techniques

| Choix | Pourquoi |
|---|---|
| State dans S3 avec `use_lockfile` | Versionné et chiffré. Le verrou natif S3 empêche deux `apply` simultanés, sans table DynamoDB. |
| Modules écrits à la main | Comprendre chaque ressource (IAM, réseau, EKS) plutôt que de les cacher derrière un module communautaire. |
| Un dossier par environnement | Chaque environnement a son state et ses variables. Les modules restent génériques. |
| Subnets sur 3 AZ, indexés par AZ (`for_each`) | Exigé par EKS et RDS. L'indexation par AZ évite les recréations en cascade qu'aurait `count`. |
| Un seul NAT Gateway | Choix de coût pour un lab. En production réelle, un NAT par AZ éviterait le point unique de panne. |
| AMI recherchée par data source | Une AMI est propre à une région et change avec les mises à jour. La data source prend la dernière Ubuntu 24.04 publiée par Canonical. |
| SSH limité à l'IP de l'administrateur | Injectée à chaque session, puisque l'IP change selon le lieu de connexion. |
| API EKS publique restreinte + privée | Le PC de l'administrateur passe par Internet (limité à son IP). Le bastion et les nœuds passent par le VPC. |
| Kubernetes 1.36 | Version par défaut d'EKS, en support standard. Une version en support étendu coûte 6 fois plus cher. |

## Prérequis

- Compte AWS et AWS CLI v2 configurée
- Terraform ≥ 1.10
- `kubectl` (au plus une version mineure d'écart avec le cluster)
- Une paire de clés SSH

## Utilisation

### 1. Backend du state (une seule fois)

```bash
cd terraform/environnements/backend_s3
terraform init
terraform apply
```

### 2. Environnement prod

Créer `terraform/environnements/prod/terraform.tfvars` (non versionné) :

```hcl
environment         = "prod"
aws_region          = "eu-west-3"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
public_subnet_cidr  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidr = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
instance_type       = "t3.micro"
hostname            = "prod-ec2-instance"
username            = "prod"
ssh_public_key      = "ssh-ed25519 AAAA..."
eks_version         = "1.36"
```

L'IP autorisée n'est pas dans le fichier : elle est injectée à chaque session.

```bash
cd terraform/environnements/prod
export TF_VAR_ssh_allowed_cidr="$(curl -s ifconfig.me)/32"

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

La création complète prend environ 15 minutes, surtout pour le cluster EKS.

### 3. Se connecter

```bash
# Bastion
$(terraform output -raw bastion_ssh_command)

# Cluster EKS, depuis le poste de l'administrateur
$(terraform output -raw eks_kubeconfig_command)
kubectl get svc
```

### 4. Détruire

```bash
terraform destroy
terraform state list   # doit être vide
```

## Coûts

Rien n'est gratuit tant que l'environnement tourne. Ordre de grandeur, hors taxes :

| Ressource | Prix approximatif |
|---|---|
| Control plane EKS | 0,10 $/h |
| NAT Gateway | ≈ 0,05 $/h + données |
| Bastion t3.micro | ≈ 0,01 $/h |
| IP publiques | ≈ 0,005 $/h chacune |

Le risque principal est d'oublier le `destroy` : un environnement laissé allumé un mois coûte plus de 100 $.

## Sécurité

- Le state et les fichiers `tfplan` contiennent toutes les valeurs **en clair**, y compris celles marquées `sensitive`. Le bucket du state est privé et chiffré. Les plans ne sont jamais commités.
- `terraform.tfvars` n'est pas versionné.
- Aucune clé d'accès AWS n'est stockée sur le bastion : l'accès au cluster passera par un rôle IAM attaché à l'instance.

## Améliorations prévues

- Fermer l'accès public à l'API EKS une fois le bastion opérationnel
- Remplacer l'accès SSH par Tailscale (installé par cloud-init)
- Un NAT Gateway par AZ en production réelle
- CI : `terraform fmt`, `validate`, `tflint` et `plan` automatique sur les pull requests