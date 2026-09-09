################################################################################
# UBUNTU AMI
#
# A thin wrapper around the generic ami-builder module, adding curated,
# toggled Ubuntu software groups (predefined packages, Docker, AWS CLI,
# Python) plus an unconditional OS baseline (system update, /opt
# preparation, Ubuntu identity validation).
#
# This module owns no AWS resources of its own -- every Image Builder
# resource is created by ami-builder. Bugs, provider-schema fixes, and new
# AWS Image Builder capabilities only need to be maintained in one place.
################################################################################

module "ami_builder" {
  source = "git::https://github.com/iamwonodi/terraform-aws-ami-builder.git?ref=v2.0.0"

  project_name = var.project_name
  environment  = var.environment
  image_name   = var.image_name

  component_description       = var.component_description
  component_build_commands    = local.component_build_commands
  component_validate_commands = local.component_validate_commands

  parent_image = var.parent_image

  component_version = var.component_version
  recipe_version    = var.recipe_version

  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  instance_types        = var.instance_types
  instance_profile_name = var.instance_profile_name
  subnet_id             = var.subnet_id
  security_group_ids    = var.security_group_ids

  key_pair                    = var.key_pair
  logging_s3_bucket_name      = var.logging_s3_bucket_name
  logging_s3_key_prefix       = var.logging_s3_key_prefix
  resource_tags               = var.resource_tags
  sns_topic_arn               = var.sns_topic_arn
  placement_tenancy           = var.placement_tenancy
  placement_availability_zone = var.placement_availability_zone

  build_image   = var.build_image
  build_trigger = var.build_trigger

  enhanced_image_metadata_enabled = var.enhanced_image_metadata_enabled

  ami_description = var.ami_description

  enable_pipeline            = var.enable_pipeline
  pipeline_schedule          = var.pipeline_schedule
  enable_image_tests         = var.enable_image_tests
  image_test_timeout_minutes = var.image_test_timeout_minutes

  tags = local.common_tags
}
