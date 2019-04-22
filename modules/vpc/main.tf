data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  count                = "${var.module_enabled ? 1 : 0}"
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = "${merge(local.tags, map("Name", "${var.stack_id}"))}"
}

resource "aws_internet_gateway" "this" {
  count  = "${var.module_enabled && local.public_subnets_count > 0 ? 1 : 0}"
  vpc_id = "${local.vpc_id}"
  tags   = "${merge(local.tags, map("Name", "ig-${var.stack_id}"))}"
}

resource "aws_route_table" "public" {
  count = "${var.module_enabled && local.public_subnets_count > 0 ? 1 : 0}"

  vpc_id = "${local.vpc_id}"

  tags = "${merge(local.tags, map("Name", "${var.stack_id}-public"))}"
}

resource "aws_route" "public_internet_gateway" {
  count = "${var.module_enabled && local.public_subnets_count > 0 ? 1 : 0}"

  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"

  timeouts {
    create = "5m"
  }
}

resource "aws_subnet" "public" {
  count             = "${var.module_enabled && local.public_subnets_count > 0 ? local.public_subnets_count : 0}"
  vpc_id            = "${local.vpc_id}"
  cidr_block        = "${element(concat(local.public_subnets, list("")), count.index)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  tags              = "${merge(local.tags, map("Name", "${var.stack_id}-public-${element(data.aws_availability_zones.available.zone_ids, count.index)}"))}"
}

resource "aws_route_table_association" "public" {
  count = "${var.module_enabled && local.public_subnets_count > 0 ? local.public_subnets_count : 0}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table" "private" {
  count  = "${var.module_enabled && local.private_subnets_count > 0 ? local.private_subnets_count : 0}"
  vpc_id = "${local.vpc_id}"
  tags   = "${merge(local.tags, map("Name", "${var.stack_id}-private-${count.index}"))}"

  lifecycle {
    ignore_changes = ["propagating_vgws"]
  }
}

resource "aws_subnet" "private" {
  count             = "${var.module_enabled && local.private_subnets_count > 0 ? local.private_subnets_count : 0}"
  vpc_id            = "${local.vpc_id}"
  cidr_block        = "${local.private_subnets[count.index]}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  tags              = "${merge(local.tags, map("Name", "${var.stack_id}-private-${element(data.aws_availability_zones.available.zone_ids, count.index)}"))}"
}

resource "aws_route_table_association" "private" {
  count          = "${var.module_enabled && local.private_subnets_count > 0 ? local.private_subnets_count : 0}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route" "private_nat_gateway" {
  count = "${var.module_enabled ? local.private_subnets_count : 0}"

  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, count.index)}"

  timeouts {
    create = "5m"
  }
}

resource "aws_eip" "nat" {
  count = "${var.module_enabled ? local.nat_gateway_count : 0}"
  vpc   = true
  tags  = "${merge(local.tags, map("Name", "${var.stack_id}-${element(data.aws_availability_zones.available.zone_ids, count.index)}"))}"
}

resource "aws_nat_gateway" "this" {
  count = "${var.module_enabled ? local.nat_gateway_count : 0}"

  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"

  tags = "${merge(local.tags, map("Name", "${var.stack_id}-${element(data.aws_availability_zones.available.zone_ids, count.index)}"))}"

  depends_on = ["aws_internet_gateway.this"]
}

resource "aws_default_security_group" "this" {
  count  = "${var.module_enabled ? 1 : 0}"
  vpc_id = "${aws_vpc.this.id}"
  tags   = "${merge(local.tags, map("Name", "sg-default-${var.stack_id}"))}"

  lifecycle {
    ignore_changes = ["ingress", "egress"]
  }
}

resource "aws_security_group_rule" "egress_allow_all" {
  count             = "${var.module_enabled ? 1 : 0}"
  description       = "Allow all outbound traffic."
  security_group_id = "${aws_default_security_group.this.id}"
  type              = "egress"
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_whitelist_allow_all" {
  count             = "${var.module_enabled ? 1 : 0}"
  description       = "All ingress traffic over VPN, for whitelisted cidrs."
  security_group_id = "${aws_default_security_group.this.id}"
  type              = "ingress"
  to_port           = 0
  from_port         = 65535
  protocol          = "-1"
  cidr_blocks       = "${var.whitelist_cidr_blocks}"
}

resource "aws_security_group_rule" "allow_ping" {
  count             = "${var.module_enabled ? 1 : 0}"
  description       = "Ping over VPN, for whitelisted cidrs."
  security_group_id = "${aws_default_security_group.this.id}"
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "ICMP"
  cidr_blocks       = "${var.whitelist_cidr_blocks}"
}

resource "aws_security_group" "public" {
  count                  = "${var.module_enabled && local.private_subnets_count > 0 ? 1 : 0}"
  vpc_id                 = "${aws_vpc.this.id}"
  name                   = "sg_public_${var.stack_id}"
  description            = "Traffic for all public compute"
  tags                   = "${merge(local.tags, map("Name", "sg-public-${var.stack_id}"))}"
  revoke_rules_on_delete = true
}

resource "aws_security_group" "private" {
  count                  = "${var.module_enabled && local.private_subnets_count > 0 ? 1 : 0}"
  vpc_id                 = "${aws_vpc.this.id}"
  name                   = "sg_private_${var.stack_id}"
  description            = "Traffic for all internal compute"
  tags                   = "${merge(local.tags, map("Name", "sg-private-${var.stack_id}"))}"
  revoke_rules_on_delete = true
}

resource "aws_security_group_rule" "internal_traffic_allow_all" {
  #count             = "${var.module_enabled && local.private_subnets_count > 0 ? 1 : 0}"
  count       = "${var.module_enabled ? 1 : 0}"
  description = "All traffic within cluster."

  #security_group_id = "${aws_security_group.private.id}"
  security_group_id = "${aws_default_security_group.this.id}"
  type              = "ingress"
  to_port           = 0
  from_port         = 65535
  protocol          = "-1"
  self              = true
}

resource "aws_default_network_acl" "this" {
  count                  = "${var.module_enabled ? 1 : 0}"
  default_network_acl_id = "${aws_vpc.this.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = "${merge(local.tags, map("Name", "acl-${var.stack_id}"))}"

  lifecycle {
    ignore_changes = ["subnet_ids"]
  }
}

resource "aws_default_route_table" "this" {
  count                  = "${var.module_enabled ? 1 : 0}"
  default_route_table_id = "${aws_vpc.this.default_route_table_id}"
  tags                   = "${merge(local.tags, map("Name", "${var.stack_id}-${var.stack_context}"))}"
}
