resource "aws_api_gateway_rest_api" "this" {
  count = var.enabled ? 1 : 0

  name        = var.name
  description = var.description
  # body        = try(var.body, null)
  api_key_source               = var.api_key_source
  binary_media_types           = var.binary_media_types
  minimum_compression_size     = var.minimum_compression_size
  disable_execute_api_endpoint = var.disable_execute_api_endpoint
  fail_on_warnings             = var.fail_on_warnings
  parameters                   = var.parameters
  put_rest_api_mode            = var.put_rest_api_mode


  dynamic "endpoint_configuration" {
    for_each = var.endpoint_configuration
    content {
      types            = endpoint_configuration.value.types
      vpc_endpoint_ids = try(endpoint_configuration.value.vpc_endpoint_ids, null)
    }
  }

  tags = var.tags
}

resource "aws_api_gateway_rest_api_policy" "this" {
  count       = var.enabled && var.rest_api_policy != null ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this[0].id

  policy = var.rest_api_policy
}

resource "aws_api_gateway_gateway_response" "this" {
  for_each = var.enabled ? var.gateway_responses : {}

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  response_type = each.key

  response_parameters = try(each.value.response_parameters, null)
  response_templates  = try(each.value.response_templates, null)
  status_code         = try(each.value.status_code, null)
}

resource "aws_api_gateway_model" "this" {
  for_each = var.enabled ? var.models : {}

  rest_api_id  = aws_api_gateway_rest_api.this[0].id
  name         = each.key
  description  = try(each.value.description, null)
  content_type = each.value.content_type
  schema       = try(each.value.schema, null)
}

resource "aws_api_gateway_deployment" "this" {
  for_each    = var.deployments
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  description = try(each.value.description, "")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_base_path_mapping" "this" {
  for_each    = var.enabled ? var.base_path_mappings : {}
  api_id      = aws_api_gateway_rest_api.this[0].id
  domain_name = each.value.domain_name
  stage_name  = try(each.value.stage_name)
  base_path   = try(each.value.base_path)

}

resource "aws_api_gateway_stage" "this" {
  # Create a flattened list of all stages in all deployments, accounting for deployments without stages
  for_each = { for idx, value in flatten([
    for deployment_id, deployment in var.deployments : [
      for stage_id, stage in try(deployment.stages, {}) : { # Use try to handle missing stages
        deployment_id = deployment_id
        stage_id      = stage_id
        stage         = stage
      }
    ]
  ]) : "${value.deployment_id}-${value.stage_id}" => value }

  deployment_id         = aws_api_gateway_deployment.this[each.value.deployment_id].id
  rest_api_id           = aws_api_gateway_rest_api.this[0].id
  stage_name            = each.value.stage_id
  xray_tracing_enabled  = try(each.value.stage.xray_tracing_enabled, null)
  cache_cluster_enabled = try(each.value.stage.cache_cluster_enabled, null)
  cache_cluster_size    = try(each.value.stage.cache_cluster_size, null)
  description           = try(each.value.stage.description, "")

  tags = try(each.value.stage.tags, {})

  variables = try(each.value.stage.variables, null)

  dynamic "access_log_settings" {
    for_each = try(each.value.stage.access_log_settings, [])

    content {
      destination_arn = access_log_settings.value.destination_arn
      format          = replace(access_log_settings.value.format, "\n", "")
    }
  }
}


# Set the logging, metrics and tracing levels for all methods
resource "aws_api_gateway_method_settings" "all" {
  for_each = var.enabled ? var.api_gateway_method_settings : {}

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  stage_name  = each.value.stage_name
  method_path = each.value.method_path

  settings {
    cache_data_encrypted                       = try(each.value.cache_data_encrypted, null)
    cache_ttl_in_seconds                       = try(each.value.cache_ttl_in_seconds, null)
    caching_enabled                            = try(each.value.caching_enabled, null)
    data_trace_enabled                         = try(each.value.data_trace_enabled, null)
    logging_level                              = try(each.value.logging_level, null)
    metrics_enabled                            = try(each.value.metrics_enabled, null)
    require_authorization_for_cache_control    = try(each.value.require_authorization_for_cache_control, null)
    throttling_burst_limit                     = try(each.value.throttling_burst_limit, null)
    throttling_rate_limit                      = try(each.value.throttling_rate_limit, null)
    unauthorized_cache_control_header_strategy = try(each.value.unauthorized_cache_control_header_strategy, null)
  }
}

# Root resource
resource "aws_api_gateway_resource" "depth_0" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 0 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = ""
  parent_id   = ""
}

# Depth 1 resources
resource "aws_api_gateway_resource" "depth_1" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 1 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_0[each.value.parent_path_part].id
}

# Depth 2 resources
resource "aws_api_gateway_resource" "depth_2" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 2 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_1[each.value.parent_path_part].id
}

# Depth 3 resources
resource "aws_api_gateway_resource" "depth_3" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 3 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_2[each.value.parent_path_part].id
}

# Depth 4 resources
resource "aws_api_gateway_resource" "depth_4" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 4 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_3[each.value.parent_path_part].id
}

# Depth 5 resources
resource "aws_api_gateway_resource" "depth_5" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 5 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_4[each.value.parent_path_part].id
}

# Depth 6 resources
resource "aws_api_gateway_resource" "depth_6" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 6 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_5[each.value.parent_path_part].id
}

# Depth 7 resources
resource "aws_api_gateway_resource" "depth_7" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 7 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_6[each.value.parent_path_part].id
}

# Depth 8 resources
resource "aws_api_gateway_resource" "depth_8" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 8 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_7[each.value.parent_path_part].id
}

# Depth 9 resources
resource "aws_api_gateway_resource" "depth_9" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 9 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_8[each.value.parent_path_part].id
}

# Depth 10 resources
resource "aws_api_gateway_resource" "depth_10" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 10 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_9[each.value.parent_path_part].id
}

# Depth 11 resources
resource "aws_api_gateway_resource" "depth_11" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 11 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_10[each.value.parent_path_part].id
}

# Depth 12 resources
resource "aws_api_gateway_resource" "depth_12" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 12 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_11[each.value.parent_path_part].id
}

# Depth 13 resources
resource "aws_api_gateway_resource" "depth_13" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 13 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_12[each.value.parent_path_part].id
}

# Depth 14 resources
resource "aws_api_gateway_resource" "depth_14" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 14 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_13[each.value.parent_path_part].id
}

# Depth 15 resources
resource "aws_api_gateway_resource" "depth_15" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 15 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_14[each.value.parent_path_part].id
}

# Depth 16 resources
resource "aws_api_gateway_resource" "depth_16" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 16 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_15[each.value.parent_path_part].id
}

# Depth 17 resources
resource "aws_api_gateway_resource" "depth_17" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 17 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_16[each.value.parent_path_part].id
}

# Depth 18 resources
resource "aws_api_gateway_resource" "depth_18" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 18 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_17[each.value.parent_path_part].id
}

# Depth 19 resources
resource "aws_api_gateway_resource" "depth_19" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 19 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_18[each.value.parent_path_part].id
}

# Depth 20 resources
resource "aws_api_gateway_resource" "depth_20" {
  for_each    = var.enabled ? { for path, info in var.resources : path => info if info.depth == 20 } : {}
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  path_part   = each.value.path_part
  parent_id   = aws_api_gateway_resource.depth_19[each.value.parent_path_part].id
}

locals {
  method_paths = merge([
    for path, info in var.resources : {
      for method, method_info in(info.methods != null ? info.methods : {}) : "${path}/${method}" => {
        path                 = path
        method               = method
        path_part            = info.path_part
        depth                = info.depth
        authorization        = method_info.authorization
        authorizer_id        = try(method_info.authorizer_id, null)
        authorization_scopes = try(method_info.authorization_scopes, null)
        api_key_required     = try(method_info.api_key_required, null)
        operation_name       = try(method_info.operation_name, null)
        request_models       = try(method_info.request_models, null)
        request_validator_id = try(method_info.request_validator_id, null)
        request_parameters   = try(method_info.request_parameters, null)
        integration          = try(method_info.integration, null)
        method_responses     = try(method_info.method_responses, null)
      }
    }
  ]...)

  all_methods = { for k, v in local.method_paths : k => v }
}

resource "aws_api_gateway_method" "depth_0" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 0 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_0[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_1" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 1 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_1[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}
resource "aws_api_gateway_method" "depth_2" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 2 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_2[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}
resource "aws_api_gateway_method" "depth_3" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 3 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_3[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_4" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 4 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_4[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_5" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 5 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_5[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_6" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 6 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_6[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_7" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 7 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_7[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_8" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 8 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_8[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_9" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 9 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_9[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_10" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 10 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_10[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_11" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 11 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_11[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}
resource "aws_api_gateway_method" "depth_12" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 12 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_12[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}
resource "aws_api_gateway_method" "depth_13" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 13 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_13[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_14" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 14 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_14[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_15" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 15 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_15[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_16" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 16 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_16[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_17" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 17 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_17[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_18" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 18 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_18[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_19" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 19 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_19[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_method" "depth_20" {
  for_each = var.enabled ? { for path, info in local.all_methods : path => info if info.depth == 20 } : {}

  rest_api_id          = aws_api_gateway_rest_api.this[0].id
  resource_id          = aws_api_gateway_resource.depth_20[each.value.path].id
  http_method          = try(each.value.method, null)
  authorization        = try(each.value.authorization, null)
  authorizer_id        = try(each.value.authorizer_id, null)
  authorization_scopes = try(each.value.authorization_scopes, null)
  api_key_required     = try(each.value.api_key_required, null)
  operation_name       = try(each.value.operation_name, null)
  request_models       = try(each.value.request_models, null)
  request_validator_id = try(each.value.request_validator_id, null)
  request_parameters   = try(each.value.request_parameters, null)
}

resource "aws_api_gateway_integration" "depth_0" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 0 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_0[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }

}

resource "aws_api_gateway_integration" "depth_1" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 1 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_1[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_2" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 2 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_2[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_3" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 3 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_3[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_4" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 4 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_4[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_5" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 5 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_5[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }
  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_6" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 6 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_6[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_7" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 7 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_7[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_8" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 8 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_8[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_9" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 9 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_9[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_10" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 10 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_10[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_11" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 11 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_11[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_12" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 12 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_12[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_13" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 13 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_13[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_14" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 14 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_14[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_15" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 15 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_15[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_16" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 16 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_16[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_17" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 17 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_17[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_18" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 18 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_18[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_19" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 19 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_19[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

resource "aws_api_gateway_integration" "depth_20" {
  for_each = var.enabled ? {
    for path, info in local.all_methods : path => info
    if info.depth == 20 && info.integration != null
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.depth_20[each.value.path].id
  http_method             = try(each.value.method, null)
  integration_http_method = try(each.value.integration.integration_http_method, null)
  type                    = try(each.value.integration.type, null)
  connection_type         = try(each.value.integration.connection_type, null)
  connection_id           = try(each.value.integration.connection_id, null)
  uri                     = try(each.value.integration.uri, null)
  credentials             = try(each.value.integration.credentials, null)
  request_templates       = try(each.value.integration.request_templates, null)
  request_parameters      = try(each.value.integration.request_parameters, null)
  passthrough_behavior    = try(each.value.integration.passthrough_behavior, null)
  cache_key_parameters    = try(each.value.integration.cache_key_parameters, null)
  cache_namespace         = try(each.value.integration.cache_namespace, null)
  content_handling        = try(each.value.integration.content_handling, null)
  timeout_milliseconds    = try(each.value.integration.timeout_milliseconds, null)

  dynamic "tls_config" {
    for_each = try(each.value.integration.tls_config != null ? each.value.integration.tls_config : [], [])
    content {
      insecure_skip_verification = try(tls_config.value.insecure_skip_verification, null)
    }
  }

  lifecycle {
    ignore_changes = [
      request_templates,
    ]
  }
}

locals {
  flattened_method_responses = merge([
    for path_method, details in local.all_methods : {
      for status_code, response in(details.method_responses != null ? details.method_responses : {}) : "${path_method}/${status_code}" => {
        path                = details.path
        method              = details.method
        status_code         = status_code
        depth               = details.depth
        response_models     = try(response.response_models, {})
        response_parameters = try(response.response_parameters, {})
      }
    }
  ]...)
}

resource "aws_api_gateway_method_response" "depth_0" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 0
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_0[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_1" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 1
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_1[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_2" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 2
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_2[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_3" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 3
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_3[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_4" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 4
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_4[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_5" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 5
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_5[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_6" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 6
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_6[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_7" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 7
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_7[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_8" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 8
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_8[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_9" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 9
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_9[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_10" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 10
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_10[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}



resource "aws_api_gateway_method_response" "depth_11" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 11
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_11[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_12" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 12
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_12[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_13" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 13
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_13[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_14" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 14
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_14[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_15" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 15
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_15[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_16" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 16
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_16[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_17" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 17
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_17[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_18" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 18
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_18[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_19" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 19
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_19[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

resource "aws_api_gateway_method_response" "depth_20" {
  for_each = var.enabled ? {
    for path, info in local.flattened_method_responses : path => info
    if info.depth == 20
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_20[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  response_models     = try(each.value.response_models, null)
  response_parameters = try(each.value.response_parameters, null)
}

locals {
  flattened_integration_responses = merge([
    for path_method, details in local.all_methods : {
      for status_code, response in(try(details.integration.responses, null) != null ? details.integration.responses : {}) : "${path_method}/${status_code}" => {
        path                = details.path
        method              = details.method
        status_code         = status_code
        depth               = details.depth
        response_templates  = try(response.response_templates, null)
        response_parameters = try(response.response_parameters, {})
        content_handling    = try(response.content_handling, null)
        selection_pattern   = try(response.selection_pattern, null)
      }
    }
  ]...)
}

resource "aws_api_gateway_integration_response" "depth_0" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 0
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_0[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_1" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 1
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_1[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_2" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 2
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_2[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_3" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 3
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_3[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}


resource "aws_api_gateway_integration_response" "depth_4" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 4
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_4[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_5" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 5
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_5[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_6" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 6
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_6[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_7" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 7
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_7[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_8" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 8
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_8[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_9" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 9
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_9[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_10" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 10
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_10[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_11" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 11
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_11[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_12" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 12
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_12[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_13" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 13
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_13[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_14" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 14
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_14[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_15" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 15
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_15[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_16" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 16
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_16[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_17" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 17
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_17[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_18" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 18
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_18[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_19" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 19
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_19[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}

resource "aws_api_gateway_integration_response" "depth_20" {
  for_each = var.enabled ? {
    for path, info in local.flattened_integration_responses : path => info
    if info.depth == 20
  } : {}

  rest_api_id         = aws_api_gateway_rest_api.this[0].id
  resource_id         = aws_api_gateway_resource.depth_20[each.value.path].id
  http_method         = each.value.method
  status_code         = each.value.status_code
  content_handling    = try(each.value.content_handling, null)
  selection_pattern   = try(each.value.selection_pattern, null)
  response_templates  = try(each.value.response_templates, null)
  response_parameters = try(each.value.response_parameters, null)

  lifecycle {
    ignore_changes = [
      response_templates,
    ]
  }
}
