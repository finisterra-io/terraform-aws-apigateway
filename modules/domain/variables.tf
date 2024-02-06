variable "enabled" {
  type        = bool
  description = "Set to false to prevent the module from creating any resources"
  default     = true
}

variable "domain_name" {
  type        = string
  description = "The domain name of the API Gateway"
}

variable "certificate_arn" {
  type        = string
  description = "The ARN of the certificate"
  default     = null
}

variable "endpoint_configuration" {
  type = list(object({
    types = list(string)
  }))
  description = "A list of endpoint types. This resource currently only supports managing a single endpoint."
  default     = []
}

variable "mutual_tls_authentication" {
  type = list(object({
    truststore_uri     = string
    truststore_version = string
  }))
  description = "A list of mutual TLS authentication configurations for a custom domain name."
  default     = []
}

variable "ownership_verification_certificate_arn" {
  type        = string
  description = "The ARN of the certificate that will be used for ownership validation."
  default     = null
}

variable "security_policy" {
  type        = string
  description = "The security policy of the custom domain name. Valid values are TLS_1_0, TLS_1_2, and TLS_1_2_2019."
  default     = null
}

variable "regional_certificate_arn" {
  type        = string
  description = "The ARN of the regional certificate to use for the custom domain name."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to the resource"
  default     = {}
}
