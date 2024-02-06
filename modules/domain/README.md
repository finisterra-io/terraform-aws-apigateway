# domain

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_domain_name.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_domain_name) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The ARN of the certificate | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name of the API Gateway | `string` | n/a | yes |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `true` | no |
| <a name="input_endpoint_configuration"></a> [endpoint\_configuration](#input\_endpoint\_configuration) | A list of endpoint types. This resource currently only supports managing a single endpoint. | <pre>list(object({<br>    types = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_mutual_tls_authentication"></a> [mutual\_tls\_authentication](#input\_mutual\_tls\_authentication) | A list of mutual TLS authentication configurations for a custom domain name. | <pre>list(object({<br>    truststore_uri     = string<br>    truststore_version = string<br>  }))</pre> | `[]` | no |
| <a name="input_ownership_verification_certificate_arn"></a> [ownership\_verification\_certificate\_arn](#input\_ownership\_verification\_certificate\_arn) | The ARN of the certificate that will be used for ownership validation. | `string` | `null` | no |
| <a name="input_regional_certificate_arn"></a> [regional\_certificate\_arn](#input\_regional\_certificate\_arn) | The ARN of the regional certificate to use for the custom domain name. | `string` | `null` | no |
| <a name="input_security_policy"></a> [security\_policy](#input\_security\_policy) | The security policy of the custom domain name. Valid values are TLS\_1\_0, TLS\_1\_2, and TLS\_1\_2\_2019. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resource | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
