# infra — AWS EKS platform: Terraform, Ansible, Jenkins, Argo CD

Production-style AWS platform, created and destroyed on demand. The infrastructure is written in Terraform with hand-built modules (no community modules) to understand every building block of an EKS cluster. Ansible configures the bastion, Jenkins builds and scans the images, and Argo CD deploys them with GitOps.

```
git push (app/) → Jenkins: build → Trivy scan → push to ECR (tag = commit hash)
               → commit "deploy(demo): <hash> [skip ci]" in gitops/ → Argo CD syncs → rolling update on EKS
```

> Learning and showcase project. The environment is created at the start of a work session (`apply`) and destroyed at the end (`destroy`).

## Progress

- [x] Terraform state backend (versioned, encrypted S3 bucket with native locking)
- [x] Multi-AZ network: VPC, public and private subnets across 3 AZs, Internet Gateway, NAT Gateway
- [x] EC2 bastion with restricted SSH access (minimal cloud-init, the rest in Ansible)
- [x] EKS control plane (IAM role, access entries)
- [x] EKS worker nodes (managed node group, Amazon Linux 2023, one node per AZ)
- [x] `kubectl` access from the bastion (instance IAM role, EKS access entry, private endpoint)
- [x] Private container registry (ECR): immutable tags, scan on push, lifecycle policy
- [x] PostgreSQL database (RDS) in private subnets, master password managed by Secrets Manager
- [x] Close public access to the EKS API: the cluster is reachable only from the bastion
- [x] Bastion configured with Ansible: dynamic AWS inventory, 6 idempotent roles (base packages, security, Docker, CLI tools, Jenkins, node_exporter)
- [x] GitOps with Argo CD: installed by Ansible (pinned Helm chart), demo app deployed from `gitops/` with automated sync, `prune` and `selfHeal`
- [x] CI pipeline in Jenkins: build, Trivy scan, push to ECR with immutable tags, tag update in `gitops/`, deployment by Argo CD
- [ ] Monitoring (Prometheus, Grafana)
- [ ] Bastion access through Tailscale, port 22 closed

## Architecture

```
  Admin workstation ── SSH (admin IP only) + tunnel to Jenkins ──┐
  Ansible control VM ── SSH (dynamic AWS inventory) ─────────────┤
┌─ Region eu-west-3 ──────────────────────────────────────────────┼─────────┐
│ ┌─ VPC 10.0.0.0/16 ─────────────────────────────────┐          │         │
│ │  Public subnets (3 AZs)    Private subnets (3 AZs) │   ┌────────────────┐│
│ │  ┌──────────────┐◄─────────────────────────────────┼───┘ EKS control    ││
│ │  │ Bastion      │──── 443, private endpoint only ──┼──►│ plane (AWS)    ││
│ │  │ t3.medium    │                                  │   └────────────────┘│
│ │  │ Jenkins, CLI │                                  │           ▲         │
│ │  └──────────────┘        ┌──────────────────┐      │           │ kubelet │
│ │  ┌──────────────┐        │ 2 EKS nodes      │──────┼───────────┘         │
│ │  │ NAT Gateway  │◄───────│ t3.medium, 1/AZ  │      │   ┌────────────────┐│
│ │  └──────────────┘        └────────┬─────────┘      │   │ S3: TF state   ││
│ │                          5432       ▼              │   └────────────────┘│
│ │                          ┌──────────────────┐      │   ┌────────────────┐│
│ │                          │ RDS PostgreSQL   │      │   │ ECR (images)   ││
│ │                          │ db.t4g.micro     │      │   │ Secrets Manager││
│ │                          └──────────────────┘      │   └────────────────┘│
│ └────────────────────────────────────────────────────┘                     │
└────────────────────────────────────────────────────────────────────────────┘
```

| Range | Role | Route to the Internet |
|---|---|---|
| `10.0.0.0/24` – `10.0.2.0/24` | Public subnets (bastion, NAT, future ALBs) | Internet Gateway |
| `10.0.3.0/24` – `10.0.5.0/24` | Private subnets (EKS nodes, control plane interfaces, RDS) | NAT Gateway |

The Kubernetes API has no public endpoint: only the bastion reaches it, from inside the VPC on port 443. The admin workstation reaches the bastion over SSH (restricted to its IP) and opens Jenkins through an SSH tunnel; no web port is exposed. Nodes have no public IP and go out through the NAT Gateway. They pull images from ECR and reach PostgreSQL on port 5432; the database is not reachable from the Internet.

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
    ├── eks/             # cluster, node group, IAM roles, access entries
    ├── registry/        # ECR repository and lifecycle policy
    └── rds/             # PostgreSQL instance, subnet group, security group
ansible/
├── ansible.cfg
├── inventories/prod/
│   ├── aws_ec2.yml      # dynamic inventory (filters on tags Role/Environment)
│   └── group_vars/      # SSH user and key, cluster name, region
├── playbooks/site.yml   # configures the bastion, one tag per role
└── roles/
    ├── common/          # base packages, /etc/apt/keyrings, python3-debian
    ├── security/        # fail2ban, ufw
    ├── docker/          # Docker Engine from the official repository
    ├── cli_tools/       # kubectl, AWS CLI v2, Helm, Trivy, kubeconfig
    ├── jenkins/         # Jenkins LTS + Java, listens on 127.0.0.1 only
    ├── node_exporter/   # Prometheus metrics, dedicated system user
    └── argocd/          # Argo CD Helm chart (pinned), initial admin password
app/
├── Dockerfile           # nginx:alpine + index.html, version injected with --build-arg
└── index.html           # demo showcase site; shows the deployed version (commit hash)
Jenkinsfile              # Prepare → Build → Scan → Push → Update GitOps
gitops/
├── apps/
│   └── demo.yaml        # Argo CD Application: which folder, which cluster, which namespace
└── demo/                # plain manifests read by Argo CD
    ├── deployment.yaml  # 2 replicas, image from ECR, requests/limits, readiness probe
    └── service.yaml     # ClusterIP
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
| Private EKS endpoint only | The Kubernetes API is not exposed on the Internet. Every `kubectl` command goes through the bastion. |
| Kubernetes 1.36 | EKS default version, in standard support. A version in extended support costs 6 times more. |
| Access entries (`authentication_mode = "API"`) | Kubernetes permissions are AWS resources managed in Terraform, instead of the legacy `aws-auth` ConfigMap. |
| Node role with `AmazonEC2ContainerRegistryPullOnly` | Least privilege: nodes can pull images from ECR and nothing more, instead of the broader `ReadOnly` policy. |
| Amazon Linux 2023 nodes | Amazon Linux 2 is no longer available for EKS nodes from Kubernetes 1.33. |
| Bastion IAM role with `eks:DescribeCluster` only | The bastion is an admin workstation, not a node: it gets the single permission `aws eks update-kubeconfig` needs. No AWS keys are stored on it. |
| ARN pattern (`cluster/prod-*`) for the bastion permission | Referencing the exact cluster ARN would create a dependency cycle between the `compute` and `eks` modules. |
| Access entries keyed by a fixed map (`{ bastion = <arn> }`) | `for_each` keys must be known at plan time; role ARNs only exist after creation. |
| Security group rule referencing the bastion's security group | The bastion is re-created when its cloud-init changes, with a new private IP. Its security group stays the same. |
| ECR tags `IMMUTABLE` | A pushed tag can never be overwritten: `v1` always points to the same image, so a deployment is reproducible and auditable. Every build gets a new tag. |
| ECR lifecycle policy (`tag_status = "any"`, keep 10) | Old images are deleted automatically, which keeps storage costs bounded. |
| `scan_on_push` | Every pushed image is scanned for known vulnerabilities. |
| `force_delete = true` (lab only) | Lets `destroy` remove a repository that still contains images. In real production it stays `false` so images cannot be lost by accident. |
| `manage_master_user_password = true` | RDS generates the password and stores it in Secrets Manager. It never appears in the Terraform code, the plan or the state. |
| RDS in private subnets, `publicly_accessible = false`, encrypted | The database is reachable only from inside the VPC, and its storage is encrypted at rest. |
| RDS security group built from a map (`allowed_security_groups`) | Ingress on 5432 only from the EKS cluster security group (carried by the nodes) and the bastion. Fixed keys (`eks_nodes`, `bastion`) because `for_each` keys must be known at plan time. |
| Lab RDS settings | `multi_az = false`, `skip_final_snapshot = true`, `deletion_protection = false`, 1 day of backups: cheap and destroyable. Real production would invert all four. |
| The RDS security group lives in the `rds` module | The rule belongs with the resource it protects; the environment only says which security groups are allowed. |
| `default_tags` on the provider, `Role = "bastion"` on the instance | Every resource carries `Environment`, `Project` and `ManagedBy`. The `Role` tag is what the Ansible inventory filters on, which also keeps the EKS nodes (EC2 instances too) out of it. |
| Minimal cloud-init, everything else in Ansible | cloud-init runs once, at first boot. Ansible can be re-run at any time, fixes drift, and its roles can be reused on servers outside AWS. cloud-init only creates the user, the SSH key and the hostname. |
| Bastion `t3.medium` | Jenkins alone uses about 400 MB of RAM, and Docker builds need more: a `t3.micro` (1 GB) would run out of memory. |
| Bastion root volume: 30 GB gp3, encrypted | The default 8 GB filled up with Docker, Jenkins, AWS CLI and the Trivy database (`no space left on device`). Encryption at rest is enabled; adding it forces a re-creation of the instance. |
| Pinned Ubuntu release in the AMI filter | An unpinned filter picks the latest Ubuntu image: a re-created bastion silently moved to a new release that the roles were not tested on. The filter targets one release (e.g. `ubuntu-noble-24.04-*`); upgrading becomes a deliberate change. |
| IMDSv2 required (`http_tokens = "required"`) | Protects the instance credentials against SSRF attacks. |
| ECR push rights on the bastion role, scoped to the repository | Jenkins pushes images with the instance role. `ecr:GetAuthorizationToken` has to be `Resource: "*"`: the login token covers the whole registry. |
| Port 9100 open only from the EKS cluster security group | The Prometheus running in the cluster will scrape node_exporter; nothing else can. |

### Ansible

| Decision | Rationale |
|---|---|
| Separate Ansible control VM | Ansible runs from a dedicated Linux VM, not from the bastion it configures. |
| Dynamic inventory (`amazon.aws.aws_ec2`) | The bastion gets a new IP at every session. The plugin finds it from its tags; `compose` sets `ansible_host` to the public IP, `hostnames` uses the `Name` tag. `keyed_groups` creates the `role_bastion` and `env_prod` groups. |
| `group_vars` next to the inventory | SSH user, key, cluster name and region are environment values, not role values. A `dev` folder gets its own. |
| `host_key_checking = False` | Lab trade-off: the bastion gets a new host key at every session. In production, `known_hosts` would be managed instead. |
| `apt` for services, pinned binaries for standalone tools | Docker, Jenkins and Java come from their official apt repositories (dependencies, systemd units, security updates). Helm and node_exporter are single binaries: a pinned version with a SHA256 checksum gives the same result every time. |
| `deb822_repository` | One `.sources` file per repository, rewritten whole: no duplicate lines when a version in the URL changes, and the key is fetched through `signed_by`. |
| Version check instead of `creates` for pinned binaries | `creates` only knows whether a file exists. Reading `--version` and comparing it with the wanted version lets the role upgrade or roll back. |
| `state: present`, never `latest` | No surprise upgrade (and restart) of Docker or Jenkins on a re-run. |
| Jenkins installed with apt, not in a container | It uses the CLI tools of the host and the instance IAM role directly, without mounting the Docker socket or raising the IMDS hop limit. |
| Jenkins on `127.0.0.1:8080`, reached through an SSH tunnel | No admin interface on the Internet, even if the security group were opened by mistake. Configured with a systemd override, so package upgrades do not overwrite it. |
| Handlers + `meta: flush_handlers` | Services restart only when their configuration changed, and before the role waits for them to listen. |
| node_exporter on the private IP, dedicated user, hardened unit | Reachable from the VPC only, runs without root, and `ProtectSystem=strict` prevents it from writing to the system. |
| One tag per role | `--tags jenkins` re-runs a single role, which also helps when a broken apt repository blocks the earlier roles. |

### Argo CD and GitOps

| Decision | Rationale |
|---|---|
| Argo CD installed by Ansible, from the bastion | The bootstrap problem: Argo CD cannot install itself. Terraform cannot do it either, since it runs on the workstation and the Kubernetes API is private. The bastion already has Helm and a kubeconfig, so an Ansible role with `kubernetes.core.helm` installs it. |
| Pinned chart version | The chart version (not the Argo CD version) is pinned; `helm search repo argo/argo-cd --versions` shows the matching app version. |
| `python3-kubernetes` on the bastion, API calls as `prod` | The `kubernetes.core` modules run on the target and need the Python client. `become: false` makes them use the kubeconfig of `prod`, not `/root/.kube/config`. |
| `argocd-server` stays `ClusterIP` | The UI is reached with `kubectl port-forward` on the bastion and an SSH tunnel from the workstation; nothing is exposed on the Internet. |
| Public repository | Argo CD reads it without credentials. In return, no secret may ever be committed: secrets will go through External Secrets. |
| Automated sync with `prune` and `selfHeal` | Git is the only source of truth: a manual `kubectl scale` is reverted within seconds, and a manifest removed from Git is removed from the cluster. |
| Image from ECR with a fixed tag (`v1`), never `latest` | The repository is immutable, and Argo CD only sees a change when the manifest changes. The CI pipeline will write a new tag per build. |
| `requests`/`limits` and a readiness probe | Two `t3.medium` nodes also run Argo CD and system pods. The probe decides when a pod receives traffic and when Argo CD reports `Healthy`. |

### CI pipeline (Jenkins)

| Decision | Rationale |
|---|---|
| `Jenkinsfile` in the repository, job "Pipeline script from SCM" | The pipeline is versioned with the code it builds. |
| Triggered manually (Poll SCM later) | Jenkins listens on `127.0.0.1`, so GitHub webhooks cannot reach it; exposing it would undo the tunnel-only access. |
| Image tag = short commit hash | Unique, and it links each image to the exact code that produced it. `BUILD_NUMBER` restarts at 1 when the bastion is re-created and would collide with the immutable repository. |
| AWS account ID read with `aws sts get-caller-identity` | Nothing account-specific is hard-coded in the public repository. |
| Skip Build/Scan/Push if the tag already exists in ECR | The repository is immutable: re-running a build on the same commit would fail on push. `aws ecr describe-images` with `returnStatus` turns that into a skipped stage instead. |
| Trivy: report HIGH + CRITICAL, fail on CRITICAL with `--ignore-unfixed` | A vulnerable image never reaches ECR, but the pipeline is not blocked by flaws nobody can fix yet. ECR `scan_on_push` adds a second check. |
| ECR login with `aws ecr get-login-password` | A 12-hour token from the instance role: no registry password stored anywhere. |
| Jenkins updates `gitops/`, never the cluster | `sed` writes the new image into `gitops/demo/deployment.yaml`, Jenkins commits and pushes, Argo CD deploys. The cluster only ever changes through Git. |
| GitHub fine-grained token, this repository only, `Contents: read and write` | Stored in Jenkins credentials (`github-token`), used through `withCredentials` in a single-quoted `sh`, so the shell reads it and Jenkins masks it in the logs. |
| `[skip ci]` in the deploy commit, checked in `Prepare` | Once polling is on, Jenkins' own commit would trigger a new build, then a new commit, forever. A `[skip ci]` commit marks the build `NOT_BUILT` and skips every stage. |
| `git checkout -B <branch> origin/<branch>`, `git diff --quiet`, `git pull --rebase` | Jenkins checks out a detached commit; nothing is committed when the tag is already in Git; a commit pushed meanwhile does not make the push fail. |
| `post { always { ... } }` cleanup | Removes the local image and the registry login after every build, so the bastion disk does not fill up. |
| `docker build` rather than `docker buildx build` | Same BuildKit engine: with `docker-buildx-plugin` installed, `docker build` is an alias. `buildx` features (multi-arch, registry cache) are not needed for one x86 image. |

## Prerequisites

- An AWS account and AWS CLI v2 configured
- Terraform ≥ 1.10
- An SSH key pair
- A Linux VM for Ansible (ansible-core ≥ 2.16, the `amazon.aws` collection, `python3-boto3`, AWS credentials). `kubectl` is no longer needed on the workstation: it is installed on the bastion.

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
instance_type           = "t3.medium"
hostname                = "prod-ec2-instance"
username                = "prod"
ssh_public_key          = "ssh-ed25519 AAAA..."
eks_version             = "1.36"
endpoint_private_access = true
endpoint_public_access  = false
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

### 3. Configure the bastion with Ansible

On the Ansible control VM (Ubuntu): Ansible from apt, plus `python3-boto3` and `python3-botocore` for the dynamic inventory, AWS credentials (`aws sts get-caller-identity` must answer), and the SSH private key matching `ssh_public_key`.

```bash
cd ansible
ansible-inventory --graph              # @role_bastion must contain the bastion, and no EKS node
ansible role_bastion -m ping           # pong

ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml    # first run on a new bastion
ansible-playbook playbooks/site.yml    # second run: changed=0
ansible-playbook playbooks/site.yml --tags jenkins   # a single role
```

`--check` cannot simulate a task that depends on the real result of the previous one: adding an apt repository, then installing a package from it, fails in check mode only.

Ad-hoc commands (`ansible ... -a`) do not gather facts: use inventory variables such as `{{ private_ip_address }}` instead of `ansible_default_ipv4`.

### 4. Connect

The Kubernetes API is private: `kubectl` runs on the bastion, whose kubeconfig is generated by Ansible.

```bash
$(terraform output -raw bastion_ssh_command)

# on the bastion
aws sts get-caller-identity   # shows assumed-role/prod-bastion-role
kubectl get nodes
```

`kubectl` authenticates with `aws eks get-token` at every call (see the `users` section of `~/.kube/config`): AWS CLI is required next to it, and no Kubernetes credential is stored on disk.

Jenkins, from the admin workstation (keep the session open):

```bash
ssh -i ~/.ssh/<key> -L 8080:localhost:8080 prod@<bastion_public_ip>
# then http://localhost:8080
```

The playbook prints the initial admin password on the first run; it is skipped once the setup wizard is done.

Run every `terraform output` command from `terraform/environments/prod`: outputs are read from the state of the current folder. If SSH warns that the host identification has changed after a re-creation, remove the old key with `ssh-keygen -R <ip>`.

### 5. Test ECR

Push from the admin workstation or from the bastion (its role can push to this repository), then run the pod from the bastion:

```bash
REPO=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin "${REPO%%/*}"

docker pull nginx:alpine
docker tag nginx:alpine "$REPO:v1"
docker push "$REPO:v1"            # a second push of v1 with another image is refused: tags are immutable

kubectl run test-ecr --image="$REPO:v1"
kubectl get pod test-ecr          # Running: the nodes pull from ECR through their role
kubectl delete pod test-ecr
```

### 6. Test RDS

The database is private, so the test runs from a pod inside the cluster (commands run on the bastion):

```bash
eval "$(terraform output -raw rds_get_password_command)"   # prints the password from Secrets Manager
terraform output -raw rds_address

kubectl run psql --image=postgres:17 --restart=Never -- sleep 3600
kubectl exec -it psql -- psql -h <rds_address> -U <username> -d <db_name>
# then: SELECT version();
kubectl delete pod psql
```

`kubectl run -it ... psql` does not work well here: the pod starts before you can type the password. Keeping a sleeping pod and attaching with `kubectl exec -it` gives an interactive prompt.

### 7. Deploy with Argo CD

```bash
ansible-playbook playbooks/site.yml --tags argocd   # installs the chart, prints the admin password

# on the bastion: push the demo image (the ECR repository is emptied by every destroy)
REPO=<ecr_repository_url>
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin "${REPO%%/*}"
docker pull nginx:alpine && docker tag nginx:alpine "$REPO:v1" && docker push "$REPO:v1"

# on the bastion, from a clone of this repository
kubectl apply -f gitops/apps/demo.yaml
kubectl get applications -n argocd   # Synced / Healthy
kubectl get pods -n demo -o wide     # one pod per node
```

Argo CD polls Git about every 3 minutes. To check right away:

```bash
kubectl -n argocd annotate application demo argocd.argoproj.io/refresh=normal --overwrite
```

Argo CD UI (two tunnels):

```bash
# on the bastion
kubectl port-forward svc/argocd-server -n argocd 8081:443
# on the workstation
ssh -i ~/.ssh/<key> -L 8081:localhost:8081 prod@<bastion_public_ip>
# then https://localhost:8081, user admin (self-signed certificate warning is expected)
```

GitOps checks performed: changing `replicas` in Git adds a pod; `kubectl scale --replicas=5` is reverted to 2 by `selfHeal`; a ConfigMap removed from Git disappears from the cluster with `prune`.

### 8. Run the CI pipeline

One-time setup per bastion (Jenkins is re-created with it, until JCasC):

1. Open Jenkins through the tunnel, unlock it with the password printed by Ansible, install the suggested plugins, create the admin user.
2. **Manage Jenkins → Credentials**: add a *Username with password* credential with ID `github-token` (GitHub user + fine-grained token).
3. **New Item → Pipeline**, "Pipeline script from SCM": Git, repository URL, branch `*/main`, script path `Jenkinsfile`.

Then:

```bash
# workstation: change something in app/, commit, push; then "Build Now" in Jenkins

# bastion: follow the deployment
kubectl -n argocd annotate application demo argocd.argoproj.io/refresh=normal --overwrite
kubectl get pods -n demo -w
kubectl get deploy nginx -n demo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# view the page: port-forward on the bastion, tunnel from the workstation
kubectl port-forward svc/nginx -n demo 8088:80
ssh -i ~/.ssh/<key> -L 8088:localhost:8088 prod@<bastion_public_ip>    # then http://localhost:8088
```

After a `destroy`, ECR is empty but Git still points to the last tag: run the pipeline before (or right after) applying the Argo CD Application, otherwise the pods stay in `ImagePullBackOff` until the first build. Jenkins pushes to the branch: `git pull` before your next commit.

### 9. Destroy

```bash
terraform destroy
terraform state list   # should be empty
rm -f tfplan
```

Never run `destroy` in `backend_s3`: the bucket holds the state of every environment. It is protected by `prevent_destroy`, so Terraform refuses and nothing is deleted.

Never force-stop an `apply` or a `destroy` (a second `Ctrl+C`, or closing the terminal): resources being created exist in AWS but never reach the state. One `Ctrl+C` stops cleanly and records what was created.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `EntityAlreadyExists` / `RepositoryAlreadyExistsException` on `apply` | A forced stop of a previous `apply` left orphaned resources outside the state | Check for duplicates (`aws ec2 describe-vpcs`, NAT gateways, EKS clusters), delete empty orphans, then `terraform import <address> <id>` for the rest and re-run `plan` |
| `no space left on device` during the Trivy scan | 8 GB root volume | `root_block_device` with 30 GB gp3 |
| `Could not get lock /var/lib/dpkg/lock-frontend` on the first Ansible run | cloud-init / unattended-upgrades still use apt on a fresh bastion | `pre_tasks` waiting for `cloud-init status --wait`, `lock_timeout` on apt tasks |
| Package versions ending in `26.04` on the bastion | Unpinned AMI filter picked a newer Ubuntu release | Pin the release in the `aws_ami` filter |
| `NO_PUBKEY` on the Jenkins repository | Old signing key (2023, expired) still in `/etc/apt/keyrings/jenkins.asc` | Delete the key file and the `.sources` file, re-run `--tags jenkins` with `jenkins.io-2026.key` |
| Pods in `ImagePullBackOff` after a re-creation | Git points to a tag that no longer exists in the emptied ECR repository | Run the pipeline |
| Argo CD still on the previous commit | It polls Git about every 3 minutes | Annotate the Application with `argocd.argoproj.io/refresh=normal` |

## Costs

Nothing is free while the environment is running. Rough estimates, excluding taxes:

| Resource | Approximate price |
|---|---|
| EKS control plane (standard support) | $0.10/h |
| 2 × t3.medium nodes (On-Demand) | ≈ $0.10/h |
| NAT Gateway | ≈ $0.05/h + data |
| t3.medium bastion | ≈ $0.05/h |
| Public IPs | ≈ $0.005/h each |
| RDS db.t4g.micro (single AZ) | ≈ $0.02/h |
| ECR, Secrets Manager | a few cents per month |
| Bastion root volume (30 GB gp3) | ≈ $0.004/h |

About $0.36/h in total, so $2–3 per work session. The main risk is forgetting the `destroy`: an environment left running for a month costs over $200. An AWS Budgets alert sends an email when spending goes over the limit.

## Security

- The state and `tfplan` files store every value **in plain text**, including those marked `sensitive`. The state bucket is private and encrypted. Plan files are never committed and are deleted after `apply`.
- `terraform.tfvars` is not committed.
- No AWS access keys are stored on the bastion: it uses temporary credentials from its instance IAM role.
- The bastion's IAM role can only describe clusters whose name starts with the environment name.
- The RDS master password is generated and stored by Secrets Manager; Terraform only knows the secret's ARN.
- The database accepts connections only from the cluster and bastion security groups.
- The Kubernetes API has no public endpoint.
- Jenkins listens on `127.0.0.1` only and is reached through an SSH tunnel.
- The `jenkins` user is in the `docker` group, which makes it root on the bastion in practice. Acceptable for a single-user lab; rootless Docker or Kaniko would remove this.
- Every downloaded binary (Helm, node_exporter) is checked against its published SHA256 checksum, and every apt repository is pinned to its signing key with `signed-by`.
- The repository is public and read by Argo CD: it never contains secrets (`terraform.tfvars`, kubeconfigs and passwords are ignored by Git).
- The Argo CD UI is not exposed: `ClusterIP` service, reached through `kubectl port-forward` and an SSH tunnel.
- The GitHub token used by Jenkins is fine-grained (this repository only, contents read/write, short expiry), lives only in Jenkins credentials and is masked in the build logs.
- Images are scanned twice (Trivy in the pipeline, ECR on push) and tags are immutable: a deployed tag always refers to the same image.
- `.gitignore` covers `*.tfvars`, `tfplan`, `*.tfstate*` and `.terraform/`; `git ls-files | grep -E 'tfvars|tfplan|tfstate'` must stay empty.

## Roadmap

- Apply the Argo CD Application from the `argocd` role, then move to the app-of-apps pattern (one root Application for `gitops/apps/`)
- Poll SCM on the Jenkins job (the `[skip ci]` guard is already in place)
- Registry cache with `buildx` in a separate mutable ECR repository, so builds stay fast on a re-created bastion
- Monitoring with Prometheus and Grafana in the cluster, scraping the bastion's node_exporter
- Configure Jenkins as code (JCasC): plugins, admin user and jobs survive a re-created bastion
- Sync the RDS secret into Kubernetes with External Secrets, then deploy an application that uses the database
- Replace SSH access with Tailscale (installed by Ansible)
- A dedicated SSH key for the Ansible control VM, instead of copying the admin key
- Move `AmazonEKS_CNI_Policy` from the node role to the `aws-node` service account (IRSA or EKS Pod Identity)
- One NAT Gateway per AZ for real production
- CI: `terraform fmt`, `validate`, `tflint` and an automatic `plan` on pull requests
