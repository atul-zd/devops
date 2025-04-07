resource "aws_key_pair" "deployer" {
  key_name   = "terra-key"
  public_key = file("/home/dev/terra-key.pub")
}

resource "aws_default_vpc" "default" {

}


data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"]
  }
}


resource "aws_security_group" "terraform-sg" {
  name        = "allow TLS"
  description = "Allow user to connect"
  vpc_id      = aws_default_vpc.default.id
  ingress {
    description = "port 22 allow"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = " allow all outgoing traffic "
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 80 allow"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 443 allow"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 443 allow"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysecurity"
  }
}

data "template_file" "ansible_playbook" {
  template = file("${path.module}/ansible-playbook.yml")
}



resource "aws_instance" "web" {
  ami = var.ami_id 
  instance_type = var.instance_type
  key_name = aws_key_pair.deployer.key_name
  subnet_id = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.terraform-sg.id]
  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -e

              apt update -y
              apt install -y software-properties-common curl

              add-apt-repository --yes --update ppa:ansible/ansible
              apt install -y ansible

              # Create a playbook
              cat <<EOL > /home/ubuntu/playbook.yml
              ${data.template_file.ansible_playbook.rendered}
              EOL

              chown ubuntu:ubuntu /home/ubuntu/playbook.yml

              # Run as the ubuntu user
              sudo -u ubuntu ansible-playbook /home/ubuntu/playbook.yml -i localhost, --connection=local
              EOF
             


  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
  tags = {
    Name = var.instance_name
  }
}



