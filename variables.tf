
################################################################################
# CORE IDENTIFICATION
################################################################################

variable "project_name" {
  type        = string
  description = "Project name used to identify the Image Builder resources."
  default     = "example"

  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment used to identify the Image Builder resources."
  default     = "development"

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}


################################################################################
# BASE IMAGE
################################################################################

variable "parent_image" {
  type        = string
  description = "Ubuntu AMI ID or Image Builder parent-image ARN used as the starting point for the base AMI."

  validation {
    condition     = trimspace(var.parent_image) != ""
    error_message = "parent_image must not be empty."
  }
}


################################################################################
# VERSIONING
################################################################################

variable "component_version" {
  type        = string
  description = "Semantic version of the Image Builder component."
  default     = "1.0.0"

  validation {
    condition = can(regex(
      "^[0-9]+\\.[0-9]+\\.[0-9]+$",
      var.component_version
    ))

    error_message = "component_version must use semantic versioning in the form X.Y.Z."
  }
}

variable "recipe_version" {
  type        = string
  description = "Semantic version of the Image Builder recipe."
  default     = "1.0.0"

  validation {
    condition = can(regex(
      "^[0-9]+\\.[0-9]+\\.[0-9]+$",
      var.recipe_version
    ))

    error_message = "recipe_version must use semantic versioning in the form X.Y.Z."
  }
}


################################################################################
# STORAGE
################################################################################

variable "root_volume_size" {
  type        = number
  description = "Size in GiB of the encrypted root EBS volume included in the resulting AMI."
  default     = 24

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "root_volume_type" {
  type        = string
  description = "EBS volume type used for the encrypted root volume."
  default     = "gp3"

  validation {
    condition = contains(
      ["gp3", "gp2"],
      lower(var.root_volume_type)
    )

    error_message = "root_volume_type must be either gp3 or gp2."
  }
}


################################################################################
# BUILD INFRASTRUCTURE
################################################################################

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types that Image Builder may use while constructing the AMI."
  default     = ["t3.medium"]

  validation {
    condition = (
      length(var.instance_types) > 0
      &&
      alltrue([
        for instance_type in var.instance_types :
        trimspace(instance_type) != ""
      ])
    )

    error_message = "instance_types must contain at least one non-empty EC2 instance type."
  }
}

variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile attached to the temporary EC2 instance used by Image Builder."

  validation {
    condition     = trimspace(var.instance_profile_name) != ""
    error_message = "instance_profile_name must not be empty."
  }
}

variable "subnet_id" {
  type        = string
  description = "Subnet where Image Builder launches the temporary EC2 build instance."

  validation {
    condition     = trimspace(var.subnet_id) != ""
    error_message = "subnet_id must not be empty."
  }
}

variable "security_group_ids" {
  type        = set(string)
  description = "Security groups attached to the temporary EC2 build instance."

  validation {
    condition = (
      length(var.security_group_ids) > 0
      &&
      alltrue([
        for security_group_id in var.security_group_ids :
        trimspace(security_group_id) != ""
      ])
    )

    error_message = "security_group_ids must contain at least one non-empty security group ID."
  }
}


################################################################################
# BUILD
################################################################################

variable "build_image" {
  type        = bool
  description = "When true, Terraform creates an Image Builder image resource and starts an AMI build."
  default     = false
}

variable "build_trigger" {
  type        = string
  description = "Optional caller-controlled value used to request a new AMI build. Change this value when an explicit manual build is required."

  default = ""
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
  description = "EventBridge cron or rate expression that determines when the Image Builder pipeline checks for and starts eligible builds."
  default     = "cron(0 3 ? * SUN *)"

  validation {
    condition     = trimspace(var.pipeline_schedule) != ""
    error_message = "pipeline_schedule must not be empty."
  }
}

variable "enable_image_tests" {
  type        = bool
  description = "Whether Image Builder runs its built-in tests against the AMI after the image build."
  default     = true
}

variable "image_test_timeout_minutes" {
  type        = number
  description = "Maximum number of minutes Image Builder allows the AMI tests to run."
  default     = 60

  validation {
    condition     = var.image_test_timeout_minutes >= 1
    error_message = "image_test_timeout_minutes must be at least 1 minute."
  }
}


################################################################################
# TAGGING
################################################################################

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to all Image Builder resources."
  default     = {}
}