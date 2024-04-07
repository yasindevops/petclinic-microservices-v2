terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "tls" {}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.mykey
  public_key = tls_private_key.example.public_key_openssh
}

output "private" {
  value = tls_private_key.example.private_key_pem
  sensitive = true
}

resource "aws_instance" "tf-rancher-server" {
  ami           = var.myami
  instance_type = var.instancetype
  key_name      = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.tf-rancher-sec-gr.id]
  iam_instance_profile = aws_iam_instance_profile.profile_for_rancher.name
  subnet_id = var.rancher-subnet
  root_block_device {
    volume_size = 16
  }
  user_data = file("rancherdata.sh")
  tags = {
    Name = var.tags
    "kubernetes.io/cluster/petclinic-Rancher" = "owned"
  }
}

resource "aws_alb_target_group" "rancher-tg" {
  name = var.tg-name
  port = 80
  protocol = "HTTP"
  vpc_id = "vpc-07d3a7cae8b930906"
  target_type = "instance"

  health_check {
    protocol = "HTTP"
    path = "/healthz"
    port = "traffic-port"
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 5
    interval = 10
  }
}

resource "aws_alb_target_group_attachment" "rancher-attach" {
  target_group_arn = aws_alb_target_group.rancher-tg.arn
  target_id = aws_instance.tf-rancher-server.id
}

data "aws_vpc" "selected" {
  default = true
}

resource "aws_lb" "rancher-alb" {
  name = var.alb-name
  ip_address_type = "ipv4"
  internal = false
  load_balancer_type = "application"
  subnets = ["subnet-025d46be72f5ca672", "subnet-042f1f0d62b2b1c92", "subnet-0188a05ca26a93126"]
  security_groups = [aws_security_group.rancher-alb.id]
}

data "aws_acm_certificate" "cert" {
  domain = var.domain-name
  statuses = [ "ISSUED" ]
  most_recent = true
}

resource "aws_alb_listener" "rancher-listener1" {
  load_balancer_arn = aws_lb.rancher-alb.arn
  port = 443
  protocol = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn = data.aws_acm_certificate.cert.arn
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.rancher-tg.arn
  }
}
resource "aws_alb_listener" "rancher-listener2" {
  load_balancer_arn = aws_lb.rancher-alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
    }
}
resource "aws_iam_policy" "policy_for_rke-controlplane_role" {
  name        = var.controlplane-policy-name
  policy      = file("cw-rke-controlplane-policy.json")
}

resource "aws_iam_policy" "policy_for_rke_etcd_worker_role" {
  name        = var.worker-policy-name
  policy      = file("cw-rke-etcd-worker-policy.json")
}

resource "aws_iam_role" "role_for_rancher" {
  name = var.rancher-role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "petclinic_role_controlplane_rke"
  }
}

resource "aws_iam_policy_attachment" "attach_for_rancher1" {
  name       = var.controlplane-attach
  roles      = [aws_iam_role.role_for_rancher.name]
  policy_arn = aws_iam_policy.policy_for_rke-controlplane_role.arn
}

resource "aws_iam_policy_attachment" "attach_for_rancher2" {
  name       = var.worker-attach
  roles      = [aws_iam_role.role_for_rancher.name]
  policy_arn = aws_iam_policy.policy_for_rke_etcd_worker_role.arn
}

resource "aws_iam_instance_profile" "profile_for_rancher" {
  name  = var.rancher-role
  role = aws_iam_role.role_for_rancher.name
}


data "aws_route53_zone" "dns" {
  name = var.hostedzone  
}

resource "aws_route53_record" "arecord" {
  name = "rancher.${data.aws_route53_zone.dns.name}"
  type = "A"
  zone_id = data.aws_route53_zone.dns.zone_id
  alias {
    name = aws_lb.rancher-alb.dns_name
    zone_id = aws_lb.rancher-alb.zone_id
    evaluate_target_health = true
  }
}

resource "null_resource" "privatekey" {
  depends_on = [tls_private_key.example]
  provisioner "local-exec" {
    command = "terraform output -raw private > ~/.ssh/${var.mykey}.pem"
  }
    provisioner "local-exec" {
      command = "cd ~/.ssh/ && chmod 400 ${var.mykey}.pem"
    }
}