################################################################################
# UBUNTU AMI - COMPLETE EXAMPLE
#
# This module is a thin wrapper around the generic ami-builder module. This
# example demonstrates the Ubuntu-specific software toggles this wrapper
# adds, while also passing through a couple of ami-builder's own fields
# (logging, key_pair) to show they still work end to end.
################################################################################

module "ubuntu_ami" {
  source = "../../"

  project_name = var.project_name
  environment  = var.environment

  ##############################################################################
  # BUILD LOGGING AND DEBUG ACCESS (pass through to ami-builder)
  ##############################################################################

  logging_s3_bucket_name = var.logging_bucket_name
  logging_s3_key_prefix  = "ubuntu-ami-logs"
  key_pair               = var.key_pair

  ##############################################################################
  # PARENT UBUNTU IMAGE
  ##############################################################################

  parent_image = var.parent_image

  ##############################################################################

  # IMAGE BUILDER COMPONENT

  #

  # These switches control optional software installed by the module:

  #

  # enable_predefined_packages = installs the standard package set:

  # git, jq, unzip, tar, gzip, curl, wget, nano,

  # ca-certificates, gnupg, lsb-release

  #

  # enable_docker = installs Docker Engine, Docker CLI, containerd,

  # Buildx, and Docker Compose

  #

  # enable_aws_cli = installs AWS CLI v2

  #

  # enable_python = installs Python 3, pip, and Python virtual-environment

  # support

  ##############################################################################

  enable_predefined_packages = var.enable_predefined_packages
  enable_docker              = var.enable_docker
  enable_aws_cli             = var.enable_aws_cli
  enable_python              = var.enable_python

  ##############################################################################

  # CUSTOM BUILD COMMANDS

  #

  # These commands are appended to the module's fixed and optional build steps.

  #

  # Keep workload-specific configuration outside the golden AMI unless it is

  # genuinely required by every workload consuming the AMI.

  ##############################################################################

  custom_build_commands = var.custom_build_commands

  ##############################################################################

  # CUSTOM VALIDATION COMMANDS

  #

  # These commands run during Image Builder validation after the build steps.

  ##############################################################################

  custom_validate_commands = var.custom_validate_commands

  ##############################################################################

  # COMPONENT AND RECIPE VERSIONING

  ##############################################################################

  component_version = var.component_version
  recipe_version    = var.recipe_version

  ##############################################################################

  # ROOT EBS VOLUME

  ##############################################################################

  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  ##############################################################################

  # IMAGE BUILDER BUILD INFRASTRUCTURE

  ##############################################################################

  instance_types        = var.instance_types
  instance_profile_name = var.instance_profile_name
  subnet_id             = var.subnet_id
  security_group_ids    = var.security_group_ids

  ##############################################################################

  # AMI BUILD

  ##############################################################################

  build_image   = var.build_image
  build_trigger = var.build_trigger

  ##############################################################################

  # OPTIONAL IMAGE BUILDER PIPELINE

  ##############################################################################

  enable_pipeline            = var.enable_pipeline
  pipeline_schedule          = var.pipeline_schedule
  enable_image_tests         = var.enable_image_tests
  image_test_timeout_minutes = var.image_test_timeout_minutes

  ##############################################################################

  # TAGGING

  ##############################################################################

  tags = var.tags
}
