# Plans the module against a mocked AWS provider. Run with "terraform test"
# (or "tofu test") from the repository root.

mock_provider "aws" {
  mock_resource "aws_imagebuilder_component" {
    defaults = {
      arn = "arn:aws:imagebuilder:af-south-1:123456789012:component/example/1.0.0/1"
    }
  }
  mock_resource "aws_imagebuilder_image_recipe" {
    defaults = {
      arn = "arn:aws:imagebuilder:af-south-1:123456789012:image-recipe/example/1.0.0"
    }
  }
  mock_resource "aws_imagebuilder_infrastructure_configuration" {
    defaults = {
      arn = "arn:aws:imagebuilder:af-south-1:123456789012:infrastructure-configuration/example"
    }
  }
  mock_resource "aws_imagebuilder_distribution_configuration" {
    defaults = {
      arn = "arn:aws:imagebuilder:af-south-1:123456789012:distribution-configuration/example"
    }
  }
}

variables {
  parent_image          = "arn:aws:imagebuilder:af-south-1:aws:image/ubuntu-server-24-lts-x86/x.x.x"
  instance_profile_name = "example-profile"
  subnet_id             = "subnet-0123456789abcdef0"
  security_group_ids    = ["sg-0123456789abcdef0"]
  enable_docker         = true
  enable_aws_cli        = true
  enable_python         = true
}

run "commands_reach_bash_as_written" {
  command = plan

  # Terraform escapes only "$${"; v2.0.0 wrote "$$(", which bash reads as its
  # process ID, so Docker's repository line named no release and Docker never
  # installed. No command may contain "$$".
  assert {
    condition     = alltrue([for c in concat(local.component_build_commands, local.component_validate_commands) : !strcontains(c, "$$")])
    error_message = "A build or validation command contains \"$$\", which bash expands to its process ID."
  }

  assert {
    condition     = strcontains(join("\n", local.component_build_commands), "https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable")
    error_message = "Docker's repository line should read the Ubuntu release from /etc/os-release."
  }

  assert {
    condition     = contains(local.component_validate_commands, "docker --version")
    error_message = "With enable_docker, validation should check Docker."
  }
}
