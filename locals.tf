################################################################################
# BASE AMI LOCALS
################################################################################

locals {
  aws_region = data.aws_region.current.region

  component_name = "${var.project_name}-${var.environment}-ubuntu-ami-ib-component"

  recipe_name = "${var.project_name}-${var.environment}-ubuntu-ami-ib-recipe"

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
    "${var.project_name}-${var.environment}-compute-ubuntu-base-ami"
  )

  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}