variable "name" {
  description = "The name of the API Gateway"
  type        = string
}

# See https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions.html for additional 
# configuration information.
variable "openapi_config" {
  description = "The OpenAPI specification for the API"
  type        = any
  default     = {}
}

variable "endpoint_type" {
  type        = list(string)
  description = "The type of the endpoint. One of - PUBLIC, PRIVATE, REGIONAL"
  default     = ["REGIONAL"]

}

variable "logging_level" {
  type        = string
  description = "The logging level of the API. One of - OFF, INFO, ERROR"
  default     = null

}

variable "metrics_enabled" {
  description = "A flag to indicate whether to enable metrics collection."
  type        = bool
  default     = false
}

variable "xray_tracing_enabled" {
  description = "A flag to indicate whether to enable X-Ray tracing."
  type        = bool
  default     = false
}

# See https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-logging.html for additional information
# on how to configure logging.
variable "access_log_format" {
  description = "The format of the access log file."
  type        = string
  default     = <<EOF
  {
	"requestTime": "$context.requestTime",
	"requestId": "$context.requestId",
	"httpMethod": "$context.httpMethod",
	"path": "$context.path",
	"resourcePath": "$context.resourcePath",
	"status": $context.status,
	"responseLatency": $context.responseLatency,
  "xrayTraceId": "$context.xrayTraceId",
  "integrationRequestId": "$context.integration.requestId",
	"functionResponseStatus": "$context.integration.status",
  "integrationLatency": "$context.integration.latency",
	"integrationServiceStatus": "$context.integration.integrationStatus",
  "authorizeResultStatus": "$context.authorize.status",
	"authorizerServiceStatus": "$context.authorizer.status",
	"authorizerLatency": "$context.authorizer.latency",
	"authorizerRequestId": "$context.authorizer.requestId",
  "ip": "$context.identity.sourceIp",
	"userAgent": "$context.identity.userAgent",
	"principalId": "$context.authorizer.principalId",
	"cognitoUser": "$context.identity.cognitoIdentityId",
  "user": "$context.identity.user"
}
  EOF
}

variable "rest_api_policy" {
  description = "The IAM policy document for the API."
  type        = string
  default     = null
}

variable "private_link_target_arns" {
  type        = list(string)
  description = "A list of target ARNs for VPC Private Link"
  default     = []
}

variable "iam_tags_enabled" {
  type        = string
  description = "Enable/disable tags on IAM roles and policies"
  default     = true
}

variable "permissions_boundary" {
  type        = string
  default     = ""
  description = "ARN of the policy that is used to set the permissions boundary for the IAM role"
}

variable "stage_name" {
  type        = string
  default     = ""
  description = "The name of the stage"
}


variable "create_api_gateway_deployment" {
  type        = bool
  default     = false
  description = "Create API Gateway Deployment"
}

variable "create_api_gateway_stage" {
  type        = bool
  default     = false
  description = "Create API Gateway Stage"
}

variable "vpc_link_enabled" {
  type        = bool
  default     = false
  description = "Enable VPC Link"
}

variable "vpc_link_name" {
  type        = string
  default     = ""
  description = "Name of the VPC Link"
}

variable "vpc_link_description" {
  type        = string
  default     = ""
  description = "Description of the VPC Link"
}

variable "description" {
  type        = string
  default     = ""
  description = "Description of the API Gateway"
}

variable "body" {
  type        = string
  default     = ""
  description = "The OpenAPI specification of the API Gateway"
}

variable "stage_tags" {
  type        = map(string)
  default     = {}
  description = "Tags to be applied to the stage"
}

variable "stage_variables" {
  type        = map(string)
  default     = {}
  description = "Stage variables to be applied to the stage"
}

variable "access_log_settings" {
  type        = list(any)
  default     = []
  description = "Access log settings for the stage"
}

variable "method_path" {
  type        = string
  default     = ""
  description = "The path of the method in API Gateway"
}

variable "cache_data_encrypted" {
  type        = bool
  default     = false
  description = "Enable encryption of cache data"
}

variable "cache_ttl_in_seconds" {
  type        = number
  default     = 300
  description = "The time-to-live (TTL) period, in seconds, that specifies how long API Gateway caches responses"
}

variable "caching_enabled" {
  type        = bool
  default     = false
  description = "Enable caching of responses"
}

variable "data_trace_enabled" {
  type        = bool
  default     = false
  description = "Enable data tracing for API Gateway"
}

variable "require_authorization_for_cache_control" {
  type        = bool
  default     = false
  description = "Enable authorization for cache control"
}

variable "throttling_burst_limit" {
  type        = number
  default     = 5000
  description = "The API request burst limit"
}

variable "throttling_rate_limit" {
  type        = number
  default     = 10000
  description = "The API request steady-state rate limit"
}

variable "unauthorized_cache_control_header_strategy" {
  type        = string
  default     = "SUCCEED_WITH_RESPONSE_HEADER"
  description = "The cache control header strategy for unauthorized responses"
}

variable "create_api_gateway_method_settings" {
  type        = bool
  default     = false
  description = "Create API Gateway Method Settings"
}


variable "stage_cache_cluster_enabled" {
  type        = bool
  default     = false
  description = "Enable cache cluster for the stage"
}

variable "stage_cache_cluster_size" {
  type        = string
  default     = null
  description = "The size of the cache cluster for the stage"
}

variable "stage_description" {
  type        = string
  default     = null
  description = "The description of the stage"
}

variable "deployment_description" {
  type        = string
  default     = null
  description = "The description of the deployment"
}

variable "stages" {
  type        = any
  default     = {}
  description = "The stages to be created"
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
  type    = string
  default = null
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
