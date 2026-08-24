################################################################################
# BASE AMI OUTPUTS
################################################################################

output "component_arn" {
  description = "ARN of the Image Builder base component."
  value       = module.base_ami.component_arn
}

output "recipe_arn" {
  description = "ARN of the Image Builder recipe."
  value       = module.base_ami.recipe_arn
}

output "infrastructure_configuration_arn" {
  description = "ARN of the Image Builder infrastructure configuration."
  value       = module.base_ami.infrastructure_configuration_arn
}

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration."
  value       = module.base_ami.distribution_configuration_arn
}

output "ami_id" {
  description = "AMI ID produced by the Image Builder build."
  value       = module.base_ami.ami_id
}

output "image_arn" {
  description = "ARN of the Image Builder image."
  value       = module.base_ami.image_arn
}

output "pipeline_arn" {
  description = "ARN of the Image Builder pipeline."
  value       = module.base_ami.pipeline_arn
}