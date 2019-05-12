output "app_ip_address" {
  value = "${aws_instance.web.public_ip}"
}

output "database_endpoint" {
  value = "${aws_db_instance.this.endpoint}"
}
