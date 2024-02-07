variable "enabled" {
  description = "A flag to enable/disable the API Gateway"
  type        = bool
  default     = true
}

variable "name" {
  description = "The name of the API Gateway"
  type        = string
}

variable "rest_api_policy" {
  description = "The IAM policy document for the API."
  type        = string
  default     = null
}

variable "description" {
  type        = string
  default     = ""
  description = "Description of the API Gateway"
}

variable "deployments" {
  type        = any
  default     = {}
  description = "The deployments to be created"
}

variable "api_gateway_method_settings" {
  type        = any
  default     = {}
  description = "The API Gateway Method Settings to be created"
}

variable "resources" {
  description = "A map of resource objects keyed by resource path"
  type = map(object({
    path_part : string
    parent_path_part : string
    depth : number
    methods : optional(map(object({
      authorization : string
      authorizer_id : optional(string)
      authorization_scopes : optional(list(string))
      api_key_required : optional(bool)
      operation_name : optional(string)
      request_models : optional(map(any))
      request_validator_id : optional(string)
      request_parameters : optional(map(bool))
      method_responses : optional(map(object({
        response_models : optional(map(any))
        response_parameters : optional(map(bool))
      })))
      integration : optional(object({
        integration_http_method : string
        type : string
        connection_type : optional(string)
        connection_id : optional(string)
        uri : string
        credentials : optional(string)
        request_templates : optional(map(string))
        request_parameters : optional(map(string))
        passthrough_behavior : optional(string)
        cache_key_parameters : optional(list(string))
        cache_namespace : optional(string)
        content_handling : optional(string)
        timeout_milliseconds : optional(number)
        tls_config : optional(list(any))
        responses : optional(map(object({ // <-- New field added
          response_templates : optional(map(string))
          response_parameters : optional(map(bool))
          content_handling : optional(string)
          selection_pattern : optional(string)
        })))
      }))
    })))
  }))
  default = {}
}

variable "api_key_source" {
  type        = string
  default     = null
  description = "The source of the API key for requests. One of - HEADER, AUTHORIZER"
}

variable "binary_media_types" {
  type        = list(string)
  default     = []
  description = "The list of binary media types supported by the RestApi. By default, the RestApi supports only UTF-8-encoded text payloads."
}

variable "minimum_compression_size" {
  type        = number
  default     = null
  description = "Minimum response size to compress for the REST API."
}

variable "disable_execute_api_endpoint" {
  type        = bool
  default     = null
  description = "Whether to disable the execute-api endpoint"
}

variable "fail_on_warnings" {
  type        = bool
  default     = null
  description = "Whether to fail on warnings"
}

variable "parameters" {
  type        = map(string)
  default     = {}
  description = "A map of stage variables to be passed to the API"
}

variable "endpoint_configuration" {
  type        = list(any)
  default     = []
  description = "A list of endpoint types. This resource currently only supports managing a single value. Valid values: EDGE, REGIONAL or PRIVATE"
}

variable "put_rest_api_mode" {
  type        = string
  description = "The mode for putting the API Gateway. Valid values are merge and overwrite. By default, merge is used."
  default     = null
}

variable "gateway_responses" {
  description = "A map of gateway response objects keyed by response type"
  type = map(object({
    status_code : string
    response_templates : optional(map(string))
    response_parameters : optional(map(string))
  }))
  default = {}
}

variable "models" {
  description = "A map of model objects keyed by model name"
  type = map(object({
    content_type : string
    description : optional(string)
    schema : string
  }))
  default = {}
}

variable "base_path_mappings" {
  description = "A map of base path mappings to create for the API Gateway"
  type = map(object({
    domain_name : string
    stage_name : optional(string)
    base_path : optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
