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

variable "image_name" {
  type        = string
  description = "Distinguishing name segment used in every Image Builder resource this module creates, passed through to ami-builder. Lets more than one AMI-producing module instance coexist within the same project_name/environment without colliding on AWS resource names."
  default     = "ubuntu"

  validation {
    condition     = trimspace(var.image_name) != ""
    error_message = "image_name must not be empty."
  }
}

################################################################################
# COMPONENT DESCRIPTIONS
#
# Ubuntu-flavored defaults -- override if a different description is wanted.
# This is the one place this module supplies its own opinion on top of what
# ami-builder otherwise leaves entirely to the caller.
################################################################################

variable "component_description" {
  type        = string
  description = "Description assigned to the Image Builder component."
  default     = "Installs common software required by platform compute instances."

  validation {
    condition     = trimspace(var.component_description) != ""
    error_message = "component_description must not be empty."
  }
}

variable "ami_description" {
  type        = string
  description = "Description assigned to the resulting AMI."
  default     = "Ubuntu golden base AMI for platform compute workloads."

  validation {
    condition     = trimspace(var.ami_description) != ""
    error_message = "ami_description must not be empty."
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

variable "key_pair" {
  type        = string
  description = "Optional EC2 key pair name for SSH access to the temporary build instance, useful for debugging a failed build."
  default     = null
}

variable "logging_s3_bucket_name" {
  type        = string
  description = "Optional S3 bucket where Image Builder uploads build logs. Required together with logging_s3_key_prefix to enable build logging."
  default     = null
}

variable "logging_s3_key_prefix" {
  type        = string
  description = "S3 key prefix under which build logs are stored, when logging_s3_bucket_name is set."
  default     = null
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags Image Builder applies to resources it creates during the build itself (the temporary EC2 instance, snapshots) -- distinct from tags, which apply to the Image Builder resources this module manages."
  default     = {}
}

variable "sns_topic_arn" {
  type        = string
  description = "Optional SNS topic ARN Image Builder publishes build and pipeline events to."
  default     = null
}

variable "placement_tenancy" {
  type        = string
  description = "Optional tenancy for the temporary build instance."
  default     = null

  validation {
    condition     = var.placement_tenancy == null || contains(["default", "dedicated", "host"], var.placement_tenancy)
    error_message = "placement_tenancy must be default, dedicated, or host."
  }
}

variable "placement_availability_zone" {
  type        = string
  description = "Optional Availability Zone for the temporary build instance."
  default     = null
}

################################################################################
# PREDEFINED SOFTWARE
#
# This is the module's actual value-add over calling ami-builder directly:
# curated, toggled Ubuntu software groups, translated into plain build/
# validate commands that ami-builder's generic interface accepts.
################################################################################

variable "enable_predefined_packages" {
  type        = bool
  description = "When true, installs the module's predefined Ubuntu package set: git, jq, unzip, tar, gzip, curl, wget, nano, ca-certificates, gnupg, and lsb-release."
  default     = true
}

variable "enable_docker" {
  type        = bool
  description = "When true, installs Docker Engine, Docker CLI, containerd, Docker Buildx, and Docker Compose from the official Docker Ubuntu repository."
  default     = false
}

variable "enable_aws_cli" {
  type        = bool
  description = "When true, installs AWS CLI version 2 using the official AWS CLI installer."
  default     = false
}

variable "enable_python" {
  type        = bool
  description = "When true, installs Python 3 and the Python 3 package manager."
  default     = false
}

################################################################################
# CUSTOM COMPONENT COMMANDS
################################################################################

variable "custom_build_commands" {
  type = list(string)

  description = <<-EOT
    Additional Bash commands supplied by the caller and executed during the
    Image Builder build phase after all enabled predefined software has been
    installed.

    Use this variable for workload-specific or organization-specific software
    that should not be maintained as part of the module's predefined software
    groups.
  EOT

  default = []

  validation {
    condition = alltrue([
      for command in var.custom_build_commands :
      trimspace(command) != ""
    ])

    error_message = "custom_build_commands must contain only non-empty commands."
  }
}

variable "custom_validate_commands" {
  type = list(string)

  description = <<-EOT
    Additional Bash commands supplied by the caller and executed during the
    Image Builder validation phase after the enabled predefined software has
    been validated.

    Use this variable to verify caller-specific software or configuration.
  EOT

  default = []

  validation {
    condition = alltrue([
      for command in var.custom_validate_commands :
      trimspace(command) != ""
    ])

    error_message = "custom_validate_commands must contain only non-empty commands."
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
  default     = ""
}

variable "enhanced_image_metadata_enabled" {
  type        = bool
  description = "Whether Image Builder collects additional metadata about the image being created. Only takes effect when build_image is true."
  default     = true
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
