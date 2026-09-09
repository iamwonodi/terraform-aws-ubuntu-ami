################################################################################
# BASE AMI OUTPUTS
################################################################################

output "component_arn" {
  description = "ARN of the Image Builder base component."
  value       = module.ubuntu_ami.component_arn
}

output "recipe_arn" {
  description = "ARN of the Image Builder recipe."
  value       = module.ubuntu_ami.recipe_arn
}

output "infrastructure_configuration_arn" {
  description = "ARN of the Image Builder infrastructure configuration."
  value       = module.ubuntu_ami.infrastructure_configuration_arn
}

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration."
  value       = module.ubuntu_ami.distribution_configuration_arn
}

output "ami_id" {
  description = "AMI ID produced by the Image Builder build."
  value       = module.ubuntu_ami.ami_id
}

output "image_arn" {
  description = "ARN of the Image Builder image."
  value       = module.ubuntu_ami.image_arn
}

output "pipeline_arn" {
  description = "ARN of the Image Builder pipeline."
  value       = module.ubuntu_ami.pipeline_arn
}