output "id" {
  description = "The ID of the VPC Link"
  value       = aws_api_gateway_vpc_link.this[0].id
}
