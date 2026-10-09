# infra — AWS EKS platform with Terraform

Production-style AWS infrastructure, created and destroyed on demand, written entirely in Terraform with hand-built modules (no community modules) to understand every building block of an EKS cluster.

> showcase project. The environment is created at the start of a work session (`apply`) and destroyed at the end (`destroy`).

## Progress

- [x] Terraform state backend (versioned, encrypted S3 bucket with native locking)
- [x] Multi-AZ network: VPC, public and private subnets across 3 AZs, Internet Gateway, NAT Gateway
- [x] EC2 bastion configured with cloud-init, restricted SSH access
- [x] EKS control plane (IAM role, restricted public endpoint + private endpoint)
- [ ] EKS worker nodes (managed node group)
- [ ] `kubectl` access from the bastion (instance IAM role, EKS access entry)
- [ ] PostgreSQL database (RDS) and image registry (ECR)
- [ ] Bastion configuration with Ansible (Jenkins, tooling)
- [ ] GitOps deployment with ArgoCD
- [ ] Monitoring (Prometheus, Grafana)
- [ ] Bastion access through Tailscale, port 22 closed

## Architecture

```
                          Internet
                             │
┌─ Region eu-west-3 ─────────┼──────────────────────────────────────────┐
│ ┌─ VPC 10.0.0.0/16 ────────┼───────────────────────────────────────┐  │
│ │                          │                                       │  │
│ │  Public subnets     Internet Gateway                             │  │
│ │  10.0.0-2.0/24           │                                       │  │
│ │   ├── EC2 bastion  ◄── SSH (admin IP only)                       │  │
│ │   └── NAT Gateway                                                │  │
│ │          │                                                       │  │
│ │  Private subnets                                                 │  │
│ │  10.0.3-5.0/24                                                   │  │
│ │   └── EKS (control plane network interfaces, nodes coming next)  │  │
│ │                                                                  │  │
│ └──────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  EKS control plane (managed by AWS)    S3: Terraform state            │
└───────────────────────────────────────────────────────────────────────┘
```

Each AZ (`eu-west-3a`, `b`, `c`) has one public and one private subnet. Private subnets reach the Internet through the NAT Gateway.

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
    ├── compute/         # bastion instance + cloud-init
    └── eks/             # EKS cluster and its IAM role
ansible/                 # coming soon
gitops/                  # coming soon
```

Each environment is a folder that calls the modules and is configured through its own `terraform.tfvars`. Adding a `dev` environment means copying the `prod` folder and changing its variables.

## Design decisions

| Decision | Rationale |
|---|---|
| State in S3 with `use_lockfile` | Versioned and encrypted. Native S3 locking prevents concurrent `apply` runs without a DynamoDB table. |
| Hand-written modules | Understand each resource (IAM, networking, EKS) instead of hiding them behind a community module. |
| One folder per environment | Each environment has its own state and variables. Modules stay generic. |
| Subnets across 3 AZs, keyed by AZ (`for_each`) | Required by EKS and RDS. Keying by AZ avoids the cascading re-creations that `count` would cause. |
| Single NAT Gateway | Cost trade-off for a lab. A real production setup would use one NAT per AZ to avoid a single point of failure. |
| AMI looked up with a data source | AMI IDs are region-specific and change with every update. The data source picks the latest Ubuntu 24.04 image published by Canonical. |
| SSH restricted to the admin IP | Injected at each session, since the IP changes depending on where I connect from. |
| Restricted public + private EKS endpoint | The admin workstation goes through the Internet (limited to its IP). The bastion and nodes go through the VPC. |
| Kubernetes 1.36 | EKS default version, in standard support. A version in extended support costs 6 times more. |

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

The allowed IP is not in the file: it is injected at each session.

```bash
cd terraform/environments/prod
export TF_VAR_ssh_allowed_cidr="$(curl -s ifconfig.me)/32"

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

A full creation takes about 15 minutes, mostly for the EKS cluster.

### 3. Connect

```bash
# Bastion
$(terraform output -raw bastion_ssh_command)

# EKS cluster, from the admin workstation
$(terraform output -raw eks_kubeconfig_command)
kubectl get svc
```

### 4. Destroy

```bash
terraform destroy
terraform state list   # should be empty
```

## Costs

Nothing is free while the environment is running. Rough estimates, excluding taxes:

| Resource | Approximate price |
|---|---|
| EKS control plane | $0.10/h |
| NAT Gateway | ≈ $0.05/h + data |
| t3.micro bastion | ≈ $0.01/h |
| Public IPs | ≈ $0.005/h each |

The main risk is forgetting the `destroy`: an environment left running for a month costs over $100.

## Security

- The state and `tfplan` files store every value **in plain text**, including those marked `sensitive`. The state bucket is private and encrypted. Plan files are never committed.
- `terraform.tfvars` is not committed.
- No AWS access keys are stored on the bastion: cluster access will go through an IAM role attached to the instance.

## Roadmap

- Close public access to the EKS API once the bastion is operational
- Replace SSH access with Tailscale (installed by cloud-init)
- One NAT Gateway per AZ for real production
- CI: `terraform fmt`, `validate`, `tflint` and an automatic `plan` on pull requests