//variable "aws_secret_key" {}
//variable "aws_access_key" {}
variable "region" {
  default = "us-east-1"
}
variable "mykey" {
  default = "firstkey1"
}
variable "tags" {
  default = "petclinic-rancher-server"
}
variable "myami" {
  description = "ubuntu 22.04 ami"
  default = "ami-07d9b9ddc6cd8dd30"
}
variable "instancetype" {
  default = "t3a.medium"
}

variable "secgrname" {
  default = "rancher-server-sec-gr"
}

variable "domain-name" {
  default = "yasinhasturk.com"
}

variable "rancher-subnet" {
  default = "subnet-025d46be72f5ca672"
}

variable "hostedzone" {
  default = "yasinhasturk.com"
}

variable "tg-name" {
  default = "clarus-rancher-http-80-tg"
}

variable "alb-name" {
  default = "petclinic-rancher-alb"
}

variable "controlplane-policy-name" {
  default = "petclinic_policy_for_rke-controlplane_role"
}

variable "worker-policy-name" {
  default = "petclinic_policy_for_rke_etcd_worker_role"
}

variable "rancher-role" {
  default = "petclinic_role_rancher"
}

variable "controlplane-attach" {
  default = "petclinic_attachment_for_rancher_controlplane"
}

variable "worker-attach" {
  default = "petclinic_attachment_for_rancher_controlplane"
}