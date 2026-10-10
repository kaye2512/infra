# infra — AWS EKS platform with Terraform

Production-style AWS infrastructure, created and destroyed on demand, written entirely in Terraform with hand-built modules (no community modules) to understand every building block of an EKS cluster.

## Progress

- [x] Terraform state backend (versioned, encrypted S3 bucket with native locking)
- [x] Multi-AZ network: VPC, public and private subnets across 3 AZs, Internet Gateway, NAT Gateway
- [x] EC2 bastion configured with cloud-init, restricted SSH access
- [x] EKS control plane (IAM role, restricted public endpoint + private endpoint)
- [x] EKS worker nodes (managed node group, Amazon Linux 2023, one node per AZ)
- [x] `kubectl` access from the bastion (instance IAM role, EKS access entry, private endpoint)
- [ ] Close public access to the EKS API (bastion only)
- [ ] PostgreSQL database (RDS) and image registry (ECR)
- [ ] Bastion configuration with Ansible (Jenkins, tooling)
- [ ] GitOps deployment with ArgoCD
- [ ] Monitoring (Prometheus, Grafana)
- [ ] Bastion access through Tailscale, port 22 closed

## Architecture

```
  Admin workstation ──── public API (admin IP only) ───────────────┐
         │                                                         │
         │ SSH (admin IP only)                                     │
┌─ Region eu-west-3 ─────────────────────────────────────────────────┼──────┐
│ ┌─ VPC 10.0.0.0/16 ─────────────────────────────────┐            ▼      │
│ │  Public subnets (3 AZs)    Private subnets (3 AZs) │   ┌────────────────┐│
│ │  ┌──────────────┐                                  │   │ EKS control    ││
│ │  │ Bastion      │──── 443, private endpoint ───────┼──►│ plane (AWS)    ││
│ │  │ IAM role,    │                                  │   └────────────────┘│
│ │  │ kubectl      │                                  │           ▲         │
│ │  └──────────────┘        ┌──────────────────┐      │           │ kubelet │
│ │  ┌──────────────┐        │ 2 EKS nodes      │──────┼───────────┘         │
│ │  │ NAT Gateway  │◄───────│ t3.medium, 1/AZ  │      │   ┌────────────────┐│
│ │  └──────────────┘        └──────────────────┘      │   │ S3: TF state   ││
│ └────────────────────────────────────────────────────┘   └────────────────┘│
└────────────────────────────────────────────────────────────────────────────┘
```

| Range | Role | Route to the Internet |
|---|---|---|
| `10.0.0.0/24` – `10.0.2.0/24` | Public subnets (bastion, NAT, future ALBs) | Internet Gateway |
| `10.0.3.0/24` – `10.0.5.0/24` | Private subnets (EKS nodes and control plane interfaces) | NAT Gateway |

The admin workstation reaches the Kubernetes API over the Internet, restricted to its IP. The bastion reaches it from inside the VPC on port 443. Nodes have no public IP and go out through the NAT Gateway.

## Repository layout

```
terraform/
├── environments/
│   ├── backend_s3/      # state bucket, created once
│   └── prod/            # wires the modules together, one state per environment
└── modules/
    ├── backend/         # S3 state bucket
    ├── network/         # VPC, subnets, routes, IGW, NAT
    ├── security/        # security groups
    ├── compute/         # bastion instance, its IAM role, cloud-init
    └── eks/             # cluster, node group, IAM roles, access entries
ansible/                 # coming soon
gitops/                  # coming soon
```

Each environment is a folder that calls the modules and is configured through its own `terraform.tfvars`. Adding a `dev` environment means copying the `prod` folder and changing its variables. Rules that connect two modules (such as the bastion-to-cluster security group rule) live in the environment folder, so no module needs to know about another.

## Design decisions

| Decision | Rationale |
|---|---|
| State in S3 with `use_lockfile` | Versioned and encrypted. Native S3 locking prevents concurrent `apply` runs without a DynamoDB table. |
| Hand-written modules | Understand each resource (IAM, networking, EKS) instead of hiding them behind a community module. |
| One folder per environment | Each environment has its own state and variables. Modules stay generic: names are built from variables, never hard-coded to `prod`. |
| Subnets across 3 AZs, keyed by AZ (`for_each`) | Required by EKS and RDS. Keying by AZ avoids the cascading re-creations that `count` would cause. |
| Single NAT Gateway | Cost trade-off for a lab. A real production setup would use one NAT per AZ to avoid a single point of failure. |
| AMI looked up with a data source | AMI IDs are region-specific and change with every update. The data source picks the latest Ubuntu 24.04 image published by Canonical. |
| SSH and public API restricted to the admin IP | Injected at each session through `TF_VAR_ssh_allowed_cidr`, since the IP changes depending on where I connect from. |
| Restricted public + private EKS endpoint | The admin workstation goes through the Internet (limited to its IP). The bastion and nodes go through the VPC. |
| Kubernetes 1.36 | EKS default version, in standard support. A version in extended support costs 6 times more. |
| Access entries (`authentication_mode = "API"`) | Kubernetes permissions are AWS resources managed in Terraform, instead of the legacy `aws-auth` ConfigMap. |
| Node role with `AmazonEC2ContainerRegistryPullOnly` | Least privilege: nodes can pull images from ECR and nothing more, instead of the broader `ReadOnly` policy. |
| Amazon Linux 2023 nodes | Amazon Linux 2 is no longer available for EKS nodes from Kubernetes 1.33. |
| Bastion IAM role with `eks:DescribeCluster` only | The bastion is an admin workstation, not a node: it gets the single permission `aws eks update-kubeconfig` needs. No AWS keys are stored on it. |
| ARN pattern (`cluster/prod-*`) for the bastion permission | Referencing the exact cluster ARN would create a dependency cycle between the `compute` and `eks` modules. |
| Access entries keyed by a fixed map (`{ bastion = <arn> }`) | `for_each` keys must be known at plan time; role ARNs only exist after creation. |
| Security group rule referencing the bastion's security group | The bastion is re-created when its cloud-init changes, with a new private IP. Its security group stays the same. |

## Prerequisites

- An AWS account and AWS CLI v2 configured
- Terraform ≥ 1.10
- `kubectl` (at most one minor version away from the cluster)
- An SSH key pair

## Usage

### 1. State backend (once)

```bash
cd terraform/environments/backend_s3
terraform init
terraform apply
```

### 2. Prod environment

Create `terraform/environments/prod/terraform.tfvars` (not committed):

```hcl
environment             = "prod"
aws_region              = "eu-west-3"
vpc_cidr                = "10.0.0.0/16"
availability_zones      = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
public_subnet_cidr      = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidr     = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
instance_type           = "t3.micro"
hostname                = "prod-ec2-instance"
username                = "prod"
ssh_public_key          = "ssh-ed25519 AAAA..."
eks_version             = "1.36"
endpoint_private_access = true
endpoint_public_access  = true
node_instance_type      = "t3.medium"
capacity_type           = "ON_DEMAND"
ami_type                = "AL2023_x86_64_STANDARD"
```

The allowed IP is not in the file: it is injected at each session. `-4` forces IPv4, since the VPC and the security groups use IPv4 only.

```bash
cd terraform/environments/prod
export TF_VAR_ssh_allowed_cidr="$(curl -4 -s ifconfig.me)/32"
echo $TF_VAR_ssh_allowed_cidr   # should look like 203.0.113.10/32

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

A full creation takes about 20 minutes, mostly for the EKS cluster and its nodes.

### 3. Connect

From the admin workstation:

```bash
$(terraform output -raw eks_kubeconfig_command)
kubectl get nodes
```

From the bastion:

```bash
$(terraform output -raw bastion_ssh_command)

# on the bastion
aws sts get-caller-identity   # shows assumed-role/prod-bastion-role
aws eks update-kubeconfig --region eu-west-3 --name prod-eks-cluster
kubectl get nodes
```

The bastion is re-created whenever its cloud-init template changes. If SSH warns that the host identification has changed, remove the old key with `ssh-keygen -R <ip>`.

### 4. Destroy

```bash
terraform destroy
terraform state list   # should be empty
rm -f tfplan
```

## Costs

Nothing is free while the environment is running. Rough estimates, excluding taxes:

| Resource | Approximate price |
|---|---|
| EKS control plane (standard support) | $0.10/h |
| 2 × t3.medium nodes (On-Demand) | ≈ $0.10/h |
| NAT Gateway | ≈ $0.05/h + data |
| t3.micro bastion | ≈ $0.01/h |
| Public IPs | ≈ $0.005/h each |

About $0.30/h in total, so $2–3 per work session. The main risk is forgetting the `destroy`: an environment left running for a month costs over $200. An AWS Budgets alert sends an email when spending goes over the limit.

## Security

- The state and `tfplan` files store every value **in plain text**, including those marked `sensitive`. The state bucket is private and encrypted. Plan files are never committed and are deleted after `apply`.
- `terraform.tfvars` is not committed.
- No AWS access keys are stored on the bastion: it uses temporary credentials from its instance IAM role.
- The bastion's IAM role can only describe clusters whose name starts with the environment name.

## Roadmap

- Close public access to the EKS API, so the cluster is reachable only from the bastion
- RDS PostgreSQL in private subnets with its password in Secrets Manager, and an ECR repository
- Configure the bastion with Ansible
- Deploy applications with ArgoCD (GitOps)
- Replace SSH access with Tailscale (installed by cloud-init)
- Move `AmazonEKS_CNI_Policy` from the node role to the `aws-node` service account (IRSA or EKS Pod Identity)
- One NAT Gateway per AZ for real production
- CI: `terraform fmt`, `validate`, `tflint` and an automatic `plan` on pull requests