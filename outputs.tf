################################################################################
# IMAGE BUILDER COMPONENT
################################################################################

output "component_arn" {
  description = "ARN of the Image Builder component used to customize the base image."
  value       = module.ami_builder.component_arn
}

################################################################################
# IMAGE RECIPE
################################################################################

output "recipe_arn" {
  description = "ARN of the Image Builder recipe used to build the base AMI."
  value       = module.ami_builder.recipe_arn
}

################################################################################
# BUILD INFRASTRUCTURE
################################################################################

output "infrastructure_configuration_arn" {
  description = "ARN of the Image Builder infrastructure configuration."
  value       = module.ami_builder.infrastructure_configuration_arn
}

################################################################################
# DISTRIBUTION
################################################################################

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration."
  value       = module.ami_builder.distribution_configuration_arn
}

################################################################################
# BUILT AMI
################################################################################

output "ami_id" {
  description = "AMI ID produced by the Image Builder build. Null when build_image is false."
  value       = module.ami_builder.ami_id
}

output "image_arn" {
  description = "ARN of the Image Builder image resource. Null when build_image is false."
  value       = module.ami_builder.image_arn
}

################################################################################
# PIPELINE
################################################################################

output "pipeline_arn" {
  description = "ARN of the Image Builder pipeline. Null when enable_pipeline is false."
  value       = module.ami_builder.pipeline_arn
}
