
################################################################################
# UBUNTU AMI - AWS EC2 IMAGE BUILDER
#
# This module creates a reusable Ubuntu-based golden AMI for platform compute
# workloads.
#
# The resulting AMI contains only software and operating-system configuration
# that should be common to multiple workloads:
#
# - Updated Ubuntu packages
# - /opt directory preparation
# - preconfigured packages
# - custom provided package
# - docker, aws-cli and python when enabled
#
# Application code, database configuration, secrets, service-specific scripts,
# Docker images, and workload-specific configuration remain caller-owned.
################################################################################


################################################################################
# IMAGE BUILDER COMPONENT
#
# The component defines the operating-system changes applied while Image
# Builder constructs the AMI.
#
# The parent image supplied through var.parent_image must be an Ubuntu image
# compatible with AWS EC2 Image Builder.
#
# IMPORTANT:
# Ubuntu uses apt rather than dnf, and the default Ubuntu administrative user
# is normally "ubuntu". Therefore this component intentionally uses apt and
# configures Docker access for the ubuntu user if docker is enabled.
#
# The actual commands are assembled in locals.tf from:
#
# - enable_predefined_packages
# - enable_docker
# - enable_aws_cli
# - custom_build_commands
# - custom_validate_commands
################################################################################

resource "aws_imagebuilder_component" "base" {
  name        = local.component_name
  platform    = "Linux"
  version     = var.component_version
  description = "Ubuntu base compute software and operating-system configuration."

  data = yamlencode({
    name          = local.component_name
    description   = "Installs common software required by platform compute instances."
    schemaVersion = 1.0

    phases = local.component_phases
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.component_name
      Type = "Ubuntu AMI Component"
    }
  )
}


################################################################################
# IMAGE RECIPE
#
# Defines the parent image, component, and root EBS volume used to construct
# the final Ubuntu-based AMI.
################################################################################

resource "aws_imagebuilder_image_recipe" "base" {
  name         = local.recipe_name
  version      = var.recipe_version
  parent_image = var.parent_image

  working_directory = "/tmp"

  component {
    component_arn = aws_imagebuilder_component.base.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.recipe_name
      Type = "Base AMI Recipe"
    }
  )
}


################################################################################
# IMAGE BUILDER INFRASTRUCTURE CONFIGURATION
#
# Defines the temporary EC2 instance AWS Image Builder launches to construct
# the AMI.
#
# The caller supplies:
#
# - Instance profile
# - Subnet
# - Security groups
# - Instance type
# - Public IP behavior
################################################################################

resource "aws_imagebuilder_infrastructure_configuration" "base" {
  name = local.infrastructure_configuration_name

  instance_types = var.instance_types

  instance_profile_name = var.instance_profile_name

  subnet_id                     = var.subnet_id
  security_group_ids            = var.security_group_ids
  terminate_instance_on_failure = true

  tags = merge(
    local.common_tags,
    {
      Name = local.infrastructure_configuration_name
      Type = "Base AMI Build Infrastructure"
    }
  )
}


################################################################################
# IMAGE BUILDER DISTRIBUTION CONFIGURATION
#
# Defines where the resulting AMI is registered.
#
# The current implementation distributes the AMI only to the AWS region in
# which Terraform is running.
################################################################################

resource "aws_imagebuilder_distribution_configuration" "base" {
  name = local.distribution_configuration_name

  distribution {
    region = local.aws_region

    ami_distribution_configuration {
      name = "${local.ami_name}-{{ imagebuilder:buildDate }}"

      description = "Ubuntu golden base AMI for platform compute workloads."

      ami_tags = merge(
        local.common_tags,
        {
          Name       = local.ami_name
          Type       = "Base AMI"
          AMIVersion = var.recipe_version
          OS         = "Ubuntu"
        }
      )
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.distribution_configuration_name
      Type = "Base AMI Distribution"
    }
  )
}


################################################################################
# IMAGE BUILDER IMAGE
#
# Creates an AMI immediately when build_image is true.
#
# When build_image is false, the Image Builder component, recipe,
# infrastructure configuration, and distribution configuration are created,
# but no AMI build is started.
################################################################################


resource "terraform_data" "build_trigger" {
  input = var.build_trigger
}


resource "aws_imagebuilder_image" "base" {
  count = var.build_image ? 1 : 0

  image_recipe_arn                 = aws_imagebuilder_image_recipe.base.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.base.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.base.arn

  tags = merge(
    local.common_tags,
    {
      Name = local.ami_name
      Type = "Base AMI Build"
    }
  )

  lifecycle {
    replace_triggered_by = [
      terraform_data.build_trigger
    ]
  }
}


################################################################################
# OPTIONAL IMAGE BUILDER PIPELINE
#
# Creates a recurring Image Builder pipeline when enable_pipeline is true.
#
# The pipeline uses the configured schedule to create updated versions of the
# golden AMI.
################################################################################

resource "aws_imagebuilder_image_pipeline" "base" {
  count = var.enable_pipeline ? 1 : 0

  name = local.pipeline_name

  image_recipe_arn                 = aws_imagebuilder_image_recipe.base.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.base.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.base.arn

  image_tests_configuration {
    image_tests_enabled = var.enable_image_tests
    timeout_minutes     = var.image_test_timeout_minutes
  }

  schedule {
    schedule_expression                = var.pipeline_schedule
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.pipeline_name
      Type = "Base AMI Pipeline"
    }
  )

  # lifecycle {
  #   replace_triggered_by = [
  #     aws_imagebuilder_image_recipe.base.version
  #   ]
  # }
}
