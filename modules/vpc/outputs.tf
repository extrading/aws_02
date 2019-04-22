output "vpc_id" {
  description = "The ID of the VPC"
  value       = "${element(concat(aws_vpc.this.*.id, list("")), 0)}"
}

output "default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation"
  value       = "${element(concat(aws_vpc.this.*.default_security_group_id, list("")), 0)}"
}

output "public_subnets" {
  value = "${compact(concat(aws_subnet.public.*.id, list("")))}"
}

output "private_subnets" {
  value = "${compact(concat(aws_subnet.private.*.id, list("")))}"
}

output "private_security_group_id" {
  value = "${element(concat(aws_security_group.private.*.id, list("")), 0)}"
}

output "public_security_group_id" {
  value = "${element(concat(aws_security_group.public.*.id, list("")), 0)}"
}
