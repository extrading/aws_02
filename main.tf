provider "aws" {
  region = "${var.aws_region}"
}

module "vpc" {
  source               = "./modules/vpc/"
  vpc_cidr             = "10.0.0.0/21"
  whitelist_cidr_blocks   = []
}

terraform {
  backend "s3" {}
}