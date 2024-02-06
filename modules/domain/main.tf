resource "aws_api_gateway_domain_name" "this" {
  count           = var.enabled ? 1 : 0
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
  dynamic "endpoint_configuration" {
    for_each = var.endpoint_configuration
    content {
      types = endpoint_configuration.value.types
    }
  }
  dynamic "mutual_tls_authentication" {
    for_each = var.mutual_tls_authentication
    content {
      truststore_uri     = mutual_tls_authentication.value.truststore_uri
      truststore_version = mutual_tls_authentication.value.truststore_version
    }
  }
  ownership_verification_certificate_arn = var.ownership_verification_certificate_arn
  security_policy                        = var.security_policy
  regional_certificate_arn               = var.regional_certificate_arn
  tags                                   = var.tags
}
