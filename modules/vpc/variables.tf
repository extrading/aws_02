locals {
  azs_count         = "${var.stack_context == "prd" ? length(data.aws_availability_zones.available.names) : 2}"
  nat_gateway_count = "${var.stack_context == "prd" ? 2 : 1}"
  vpc_id            = "${element(concat(aws_vpc.this.*.id, list("")), 0)}"

  public_subnets        = ["${cidrsubnet(var.vpc_cidr, 3, 0)}", "${cidrsubnet(var.vpc_cidr, 3, 1)}"]
  private_subnets       = ["${cidrsubnet(var.vpc_cidr, 2, 1)}", "${cidrsubnet(var.vpc_cidr, 2, 2)}"]
  private_subnets_count = "${length(local.private_subnets)}"
  public_subnets_count  = "${length(local.public_subnets)}"
  tags                  = "${merge(var.tags, map( "module_name", "vpc" ))}"
}

variable "module_enabled" {
  description = "Switch for creating resources."
  default     = true
}

variable "stack_id" {
  description = "Name to be used on all the resources as identifier"
  default     = "noname"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  default     = {}
}

variable "whitelist_cidr_blocks" {
  default = []
}

variable "stack_context" {
  default     = "dev"
  description = "this is"
}
