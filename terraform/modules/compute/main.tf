resource "aws_instance" "server" {
  ami          = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "dev-team-instance"
  }
}