
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
# - Git
# - jq
# - unzip
# - tar
# - gzip
# - curl
# - wget
# - nano
# - Docker
# - AWS CLI v2
# - /opt directory preparation
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
# configures Docker access for the ubuntu user.
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

    phases = [
      ############################################################################
      # BUILD PHASE
      #
      # Installs and configures the software that should exist on every compute
      # instance created from this golden AMI.
      ############################################################################
      {
        name = "build"

        steps = [
          {
            name      = "UpdateSystemPackages"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "export DEBIAN_FRONTEND=noninteractive",
                "apt-get update -y",
                "apt-get upgrade -y"
              ]
            }
          },

          {
            name      = "InstallBasePackages"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "export DEBIAN_FRONTEND=noninteractive",
                "apt-get install -y git jq unzip tar gzip curl wget nano ca-certificates gnupg lsb-release"
              ]
            }
          },

          {
            name      = "InstallDocker"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "install -m 0755 -d /etc/apt/keyrings",
                "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
                "chmod a+r /etc/apt/keyrings/docker.asc",
                "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $${UBUNTU_CODENAME:-$$VERSION_CODENAME}) stable\" > /etc/apt/sources.list.d/docker.list",
                "apt-get update -y",
                "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
                "systemctl enable docker",
                "systemctl start docker",
                "usermod -aG docker ubuntu"
              ]
            }
          },

          {
            name      = "InstallAWSCLI"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip",
                "rm -rf /tmp/aws",
                "unzip -q /tmp/awscliv2.zip -d /tmp",
                "/tmp/aws/install",
                "rm -rf /tmp/aws /tmp/awscliv2.zip"
              ]
            }
          },

          {
            name      = "PrepareComputeDirectories"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "mkdir -p /opt",
                "chmod 755 /opt"
              ]
            }
          }
        ]
      },

      ############################################################################
      # VALIDATE PHASE
      #
      # Confirms that the software installed during the build phase is available
      # before Image Builder creates the final AMI.
      ############################################################################
      {
        name = "validate"

        steps = [
          {
            name      = "ValidateDocker"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "docker --version",
                "docker compose version",
                "systemctl is-enabled docker"
              ]
            }
          },

          {
            name      = "ValidateAWSCLI"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "aws --version"
              ]
            }
          },

          {
            name      = "ValidateNano"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "nano --version"
              ]
            }
          },

          {
            name      = "ValidateBasePackages"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "git --version",
                "jq --version",
                "curl --version"
              ]
            }
          },

          {
            name      = "ValidateUbuntu"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "test -f /etc/os-release",
                "grep -q 'Ubuntu' /etc/os-release"
              ]
            }
          }
        ]
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.component_name
      Type = "Base AMI Component"
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
