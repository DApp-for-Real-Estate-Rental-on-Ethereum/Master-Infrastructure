output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_host" {
  value = aws_db_instance.main.address
}
