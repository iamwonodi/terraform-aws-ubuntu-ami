################################################################################
# BASE AMI EXAMPLE
################################################################################

module "ubuntu_ami" {
  source = "../../"

  project_name = var.project_name
  environment  = var.environment

  parent_image = var.parent_image

  component_version = var.component_version
  recipe_version    = var.recipe_version

  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  instance_types        = var.instance_types
  instance_profile_name = var.instance_profile_name
  subnet_id             = var.subnet_id
  security_group_ids    = var.security_group_ids

  build_image   = var.build_image
  build_trigger = var.build_trigger

  enable_pipeline            = var.enable_pipeline
  pipeline_schedule          = var.pipeline_schedule
  enable_image_tests         = var.enable_image_tests
  image_test_timeout_minutes = var.image_test_timeout_minutes

  tags = var.tags
}