# Optionally create a VPC Link to allow the API Gateway to communicate with private resources (e.g. ALB)
resource "aws_api_gateway_vpc_link" "this" {
  count       = var.enabled ? 1 : 0
  name        = var.name
  description = var.description
  target_arns = var.target_arns
  tags        = var.tags
}
