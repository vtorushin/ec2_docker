terraform {
  required_version = ">= 0.12.9"
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_instance" "vpc_docker" {
  count = var.vpc_count
  ami             = var.aws_ami_id
  instance_type   = var.inst_type
  key_name = var.workpc_pub_key_name
  tags = {
    Name = format("%s%s", var.vpc_name, count.index)
  }
}

resource "null_resource" "GenProductionFile1" {
  provisioner "local-exec" {
  command = <<-EOF
              #!/bin/bash
              echo "---" > production
              echo "all:" >> production
              echo "  children:" >> production
              echo "    docker:" >> production
              echo "      hosts:" >> production
              EOF
  }
}

resource "null_resource" "GenProductionFile2" {
  count = var.vpc_count

  connection {
    host = element(aws_instance.vpc_docker.*.public_ip, count.index)
    type     = "ssh"
    user = "ubuntu"
    private_key = file(var.workpc_pub_key_path)
    timeout = "3m"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${var.vpc_name}${count.index}"
    ]
  }

  provisioner "local-exec" {
    command = "echo '        '${element(aws_instance.vpc_docker.*.public_ip, count.index)}:  >> production"
	}
  depends_on = [null_resource.GenProductionFile1]
}

resource "null_resource" "ProductionHeader3"{
  provisioner "local-exec" {
    command = "ansible-playbook docker_install.yml"
  }
  depends_on = [null_resource.GenProductionFile2]
}
