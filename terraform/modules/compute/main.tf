resource "aws_instance" "server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  user_data = templatefile("${path.module}/templates/user-data.tpl", {
    hostname       = var.hostname
    username       = var.username
    ssh_public_key = var.ssh_public_key
  })

  tags = {
    Name = var.instance_name
  }
}