output "id" {
  description = "The ID of the domain name"
  value       = aws_api_gateway_domain_name.this[0].id
}
