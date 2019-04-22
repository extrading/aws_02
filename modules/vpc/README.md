
# private subnets
private_subnets = "${cidrsubnet(var.cidr, 2, 2)}"
Splits VPC into subnets. 64 addresses per subnet.

# cidrsubnet(iprange, newbits, netnum) arguments:

iprange: this is the original ip address which needs to be modified
newbits: the original bitmask (e.g. 24 in our example)  – the required bitmask (e.g. 28and 27 in our examples)
netnum: (Required IP Range) ÷ (2 power (32 – required bitmask) ). For example: To get 10.130.10.160/27, it would be (160) ÷ (2 power (32-27)) = (160) ÷ (32) = 5.