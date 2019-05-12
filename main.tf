provider "aws" {
  region = "${var.aws_region}"
}

module "vpc" {
  source                = "./modules/vpc/"
  vpc_cidr              = "10.0.0.0/21"
  whitelist_cidr_blocks = ["10.0.0.0/32"]
}

terraform {
  backend "s3" {}
}

## TASK 1
resource "aws_security_group" "app" {
  name        = "App-SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "DB-SG"
  description = "Allow DB access"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    description     = "Application accessing ports of MYSQL/Aurora"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.app.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## TASK 2

resource "aws_db_subnet_group" "this" {
  name       = "${random_pet.stack_name.id}"
  subnet_ids = ["${module.vpc.public_subnets}"]
}

resource "aws_db_instance" "this" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  identifier             = "inventory-db"
  name                   = "inventory"
  username               = "master"
  password               = "lab-password"
  db_subnet_group_name   = "${aws_db_subnet_group.this.name}"
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
  multi_az               = false
  skip_final_snapshot    = true
  apply_immediately      = true
}

# resource "random_string" "better_way" {
#   length = 16
#   special = true
# }

# resource "aws_db_instance" "example" {
#   password = "${random_string.better_way.result}"
# }

## TASK 3

data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/user-data.sh")}"
}

resource "aws_instance" "web" {
  ami                         = "${data.aws_ami.this.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${element(module.vpc.public_subnets, 0)}"
  vpc_security_group_ids      = ["${aws_security_group.app.id}"]
  user_data                   = "${data.template_file.user_data.rendered}"
  key_name                    = "${aws_key_pair.this.key_name}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.this.id}"

  tags = {
    Name = "App Server"
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${random_pet.stack_name.id}"
  public_key = "${tls_private_key.this.public_key_openssh}"
}
