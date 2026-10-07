#cloud-config

hostname: ${hostname}
timezone: Europe/Paris
ssh_pwauth: false
package_update: true
package_upgrade: true
packages:
  - git
  - python3-pip

users:
  - name: ${username}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}

