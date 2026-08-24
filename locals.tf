################################################################################
# UBUNTU AMI LOCALS
#
# This file assembles the build and validation commands used by the Image
# Builder component.
#
# The caller can enable predefined software groups and can also provide
# additional custom commands.
################################################################################

locals {
  aws_region = data.aws_region.current.region

  component_name = "${var.project_name}-${var.environment}-ubuntu-ami-component"

  recipe_name = "${var.project_name}-${var.environment}-ubuntu-ami-recipe"

  infrastructure_configuration_name = (
    "${var.project_name}-${var.environment}-ubuntu-ami-build"
  )

  distribution_configuration_name = (
    "${var.project_name}-${var.environment}-ubuntu-ami-distribution"
  )

  pipeline_name = (
    "${var.project_name}-${var.environment}-ubuntu-ami-pipeline"
  )

  ami_name = (
    "${var.project_name}-${var.environment}-ubuntu-compute"
  )

  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      OS          = "Ubuntu"
    }
  )

  ################################################################################
  # PREDEFINED UBUNTU PACKAGES
  #
  # These packages are installed when enable_predefined_packages is true.
  #
  # Package purpose:
  #
  # git            - Source-control client.
  # jq             - JSON command-line processor.
  # unzip          - ZIP archive extraction utility.
  # tar            - TAR archive utility.
  # gzip           - GZIP compression utility.
  # curl           - HTTP/HTTPS command-line client.
  # wget           - File download utility.
  # nano           - Terminal text editor.
  # ca-certificates - Trusted CA certificates for TLS connections.
  # gnupg          - GPG tooling used to verify package repositories.
  # lsb-release    - Linux distribution information utilities.
  ################################################################################

  predefined_package_install_commands = var.enable_predefined_packages ? [
    "export DEBIAN_FRONTEND=noninteractive",
    "apt-get update -y",
    "apt-get install -y git jq unzip tar gzip curl wget nano ca-certificates gnupg lsb-release"
  ] : []

  predefined_package_validate_commands = var.enable_predefined_packages ? [
    "git --version",
    "jq --version",
    "unzip -v",
    "tar --version",
    "gzip --version",
    "curl --version",
    "wget --version",
    "nano --version"
  ] : []

  ################################################################################
  # DOCKER INSTALLATION
  #
  # Docker is installed from Docker's official Ubuntu repository rather than
  # relying on Ubuntu's distribution package.
  ################################################################################

  docker_install_commands = var.enable_docker ? [
    "install -m 0755 -d /etc/apt/keyrings",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
    "chmod a+r /etc/apt/keyrings/docker.asc",
    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $${UBUNTU_CODENAME:-$$VERSION_CODENAME}) stable\" > /etc/apt/sources.list.d/docker.list",
    "apt-get update -y",
    "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
    "systemctl enable docker",
    "systemctl start docker",
    "usermod -aG docker ubuntu"
  ] : []

  docker_validate_commands = var.enable_docker ? [
    "docker --version",
    "docker compose version",
    "systemctl is-enabled docker"
  ] : []

  ################################################################################
  # AWS CLI INSTALLATION
  #
  # Installs AWS CLI version 2 using the official AWS installer.
  ################################################################################

  aws_cli_install_commands = var.enable_aws_cli ? [
    "curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip",
    "rm -rf /tmp/aws",
    "unzip -q /tmp/awscliv2.zip -d /tmp",
    "/tmp/aws/install",
    "rm -rf /tmp/aws /tmp/awscliv2.zip"
  ] : []

  aws_cli_validate_commands = var.enable_aws_cli ? [
    "aws --version"
  ] : []

  ################################################################################
  # PYTHON INSTALLATION
  #
  # Installs PYTHON & its package manager PIP using the apt package manager
  ################################################################################

  python_commands = var.enable_python ? [
    "export DEBIAN_FRONTEND=noninteractive",
    "apt-get install -y python3 python3-pip python3-venv"
  ] : []

  ################################################################################
  # COMBINED COMPONENT COMMANDS
  #
  # Predefined commands are executed first. Caller-supplied commands are then
  # executed afterwards so the caller can build on the predefined software.
  ################################################################################

  component_build_commands = concat(
    local.predefined_package_install_commands,
    local.docker_install_commands,
    local.aws_cli_install_commands,
    local.python_commands,
    var.custom_build_commands
  )

  component_validate_commands = concat(
    local.predefined_package_validate_commands,
    local.docker_validate_commands,
    local.aws_cli_validate_commands,
    var.custom_validate_commands
  )

  ################################################################################
  # IMAGE BUILDER COMPONENT PHASES
  #
  # The validate phase is included only when there is at least one validation
  # command. This prevents Image Builder from receiving an empty validation step.
  ################################################################################

  component_phases = concat(
    [
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
            name      = "PrepareComputeDirectories"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = [
                "mkdir -p /opt",
                "chmod 755 /opt"
              ]
            }
          },
          {
            name      = "InstallAndConfigureSoftware"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = local.component_build_commands
            }
          }
        ]
      }
    ],

    [
      {
        name = "validate"

        steps = [
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
          },
          {
            name      = "ValidateSoftwareInstallation"
            action    = "ExecuteBash"
            onFailure = "Abort"

            inputs = {
              commands = length(local.component_validate_commands) > 0 ? local.component_validate_commands : ["echo 'No custom validation commands configured.'"]
            }
          }
        ]
      }
    ]
  )
}