variable "enabled" {
  type        = bool
  description = "Set to false to prevent the module from creating any resources"
  default     = true
}

variable "name" {
  type        = string
  description = "The name of the REST API"
}

variable "description" {
  type        = string
  description = "The description of the REST API"
  default     = ""
}

variable "target_arns" {
  type        = list(any)
  description = "The list of private target ARNs for the VPC Link"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource"
  default     = {}
}
