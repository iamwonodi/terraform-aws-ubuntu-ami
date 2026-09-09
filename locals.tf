################################################################################
# UBUNTU AMI LOCALS
#
# Assembles the build and validation commands passed to the ami-builder
# module. ami-builder's component only has a flat build phase and a flat
# validate phase (a single Bash step each) -- the OS-baseline steps this
# module used to run as separate named Image Builder phases (system update,
# /opt preparation, Ubuntu identity check) are folded in here as ordinary
# commands instead, always first in their respective list.
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      OS          = "Ubuntu"
    }
  )

  ##############################################################################
  # OS BASELINE (always run, not caller-toggleable)
  ##############################################################################

  system_update_commands = [
    "export DEBIAN_FRONTEND=noninteractive",
    "apt-get update -y",
    "apt-get upgrade -y",
  ]

  compute_directory_commands = [
    "mkdir -p /opt",
    "chmod 755 /opt",
  ]

  os_validation_commands = [
    "test -f /etc/os-release",
    "grep -q 'Ubuntu' /etc/os-release",
  ]

  ##############################################################################
  # PREDEFINED UBUNTU PACKAGES
  #
  # Installed when enable_predefined_packages is true.
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
  ##############################################################################

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

  ##############################################################################
  # DOCKER INSTALLATION
  #
  # Docker is installed from Docker's official Ubuntu repository rather than
  # relying on Ubuntu's distribution package.
  ##############################################################################

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

  ##############################################################################
  # AWS CLI INSTALLATION
  #
  # Installs AWS CLI version 2 using the official AWS installer.
  ##############################################################################

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

  ##############################################################################
  # PYTHON INSTALLATION
  #
  # Installs Python and its package manager pip using the apt package manager.
  ##############################################################################

  python_commands = var.enable_python ? [
    "export DEBIAN_FRONTEND=noninteractive",
    "apt-get install -y python3 python3-pip python3-venv"
  ] : []

  python_validate_commands = var.enable_python ? [
    "python3 --version",
    "python3 -m pip --version",
    "python3 -m venv --help"
  ] : []

  ##############################################################################
  # COMBINED COMMANDS PASSED TO ami-builder
  #
  # OS baseline commands run first, then predefined packages, then optional
  # software groups, then any caller-supplied commands -- so the caller can
  # build on top of everything this module already installed.
  ##############################################################################

  component_build_commands = concat(
    local.system_update_commands,
    local.compute_directory_commands,
    local.predefined_package_install_commands,
    local.docker_install_commands,
    local.aws_cli_install_commands,
    local.python_commands,
    var.custom_build_commands,
  )

  component_validate_commands = concat(
    local.os_validation_commands,
    local.predefined_package_validate_commands,
    local.docker_validate_commands,
    local.aws_cli_validate_commands,
    local.python_validate_commands,
    var.custom_validate_commands,
  )
}
