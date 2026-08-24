################################################################################
# IMAGE BUILDER COMPONENT
################################################################################

output "component_arn" {
  description = "ARN of the Image Builder component used to customize the base image."
  value       = aws_imagebuilder_component.base.arn
}


################################################################################
# IMAGE RECIPE
################################################################################

output "recipe_arn" {
  description = "ARN of the Image Builder recipe used to build the base AMI."
  value       = aws_imagebuilder_image_recipe.base.arn
}


################################################################################
# BUILD INFRASTRUCTURE
################################################################################

output "infrastructure_configuration_arn" {
  description = "ARN of the Image Builder infrastructure configuration."
  value       = aws_imagebuilder_infrastructure_configuration.base.arn
}


################################################################################
# DISTRIBUTION
################################################################################

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration."
  value       = aws_imagebuilder_distribution_configuration.base.arn
}


################################################################################
# BUILT AMI
################################################################################

output "ami_id" {
  description = "AMI ID produced by the Image Builder build. Returns null when build_image is false."

  value = (
    var.build_image
    ? try(one(aws_imagebuilder_image.base[0].output_resources).amis[0].image, null)
    : null
  )
}

output "image_arn" {
  description = "ARN of the Image Builder image resource. Returns null when build_image is false."

  value = (
    var.build_image
    ? aws_imagebuilder_image.base[0].arn
    : null
  )
}


################################################################################
# PIPELINE
################################################################################

output "pipeline_arn" {
  description = "ARN of the Image Builder pipeline. Null when enable_pipeline is false."
  value = (
    var.enable_pipeline
    ? aws_imagebuilder_image_pipeline.base[0].arn
    : null
  )
}