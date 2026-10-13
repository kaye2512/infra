#cloud-config

hostname: ${hostname}
timezone: Europe/Paris
ssh_pwauth: false
package_update: true
package_upgrade: true
packages:
  - git
  - python3-pip
  - unzip

users:
  - name: ${username}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}

runcmd:
  # AWS CLI v2 (méthode officielle AWS)
  - curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  - unzip -q /tmp/awscliv2.zip -d /tmp
  - /tmp/aws/install
  # kubectl, version alignée sur le cluster
  - curl -sSL "https://dl.k8s.io/release/v${kubectl_version}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
  - chmod +x /usr/local/bin/kubectl
  - echo 'aws eks update-kubeconfig --region eu-west-3 --name prod-eks-cluster > /dev/null 2>&1' >> /home/${username}/.bashrc