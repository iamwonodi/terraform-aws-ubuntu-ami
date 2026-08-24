################################################################################
# CORE IDENTIFICATION
################################################################################

variable "project_name" {
  type        = string
  description = "Project name used to identify the base AMI resources."
  default     = "blueprints"
}

variable "environment" {
  type        = string
  description = "Environment used for the example deployment."
  default     = "development"
}


################################################################################
# BASE IMAGE
################################################################################

variable "parent_image" {
  type        = string
  description = "UBUNTU AMI ID or Image Builder parent-image ARN."
}


################################################################################
# VERSIONING
################################################################################

variable "component_version" {
  type        = string
  description = "Version of the Image Builder component."
  default     = "1.0.0"
}

variable "recipe_version" {
  type        = string
  description = "Version of the Image Builder recipe."
  default     = "1.0.0"
}


################################################################################
# STORAGE
################################################################################

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB."
  default     = 24
}

variable "root_volume_type" {
  type        = string
  description = "Root EBS volume type."
  default     = "gp3"
}


################################################################################
# BUILD INFRASTRUCTURE
################################################################################

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types used during AMI creation."
  default     = ["t3.medium"]
}

variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile used by Image Builder."
}

variable "subnet_id" {
  type        = string
  description = "Subnet used by the temporary Image Builder build instance."
}

variable "security_group_ids" {
  type        = set(string)
  description = "Security groups attached to the temporary Image Builder instance."
}



################################################################################
# BUILD
################################################################################

variable "build_image" {
  type        = bool
  description = "Whether to perform the AMI build."
  default     = false
}

variable "build_trigger" {
  type        = string
  description = "Optional value used to explicitly request a new AMI build. Change this value when a manual build is required."
  default     = ""
}


################################################################################
# PIPELINE
################################################################################

variable "enable_pipeline" {
  type        = bool
  description = "Whether to create the recurring Image Builder pipeline."
  default     = false
}

variable "pipeline_schedule" {
  type        = string
  description = "Image Builder pipeline schedule."
  default     = "cron(0 3 ? * SUN *)"
}

variable "enable_image_tests" {
  type        = bool
  description = "Whether Image Builder performs image tests."
  default     = true
}

variable "image_test_timeout_minutes" {
  type        = number
  description = "Image test timeout in minutes."
  default     = 60
}


################################################################################
# TAGGING
################################################################################

variable "tags" {
  type        = map(string)
  description = "Additional tags for the example deployment."
  default = {
    ManagedBy = "Terraform"
  }
}