# Terraform AWS Ubuntu AMI

A thin, opinionated wrapper around the generic `terraform-aws-ami-builder` module, providing curated Ubuntu software toggles on top of it: predefined packages, Docker, AWS CLI, and Python -- plus an unconditional OS baseline (system update, `/opt` preparation, Ubuntu identity validation).

This module owns no AWS resources of its own. Every `aws_imagebuilder_*` resource is created by `ami-builder`; this module's entire job is translating Ubuntu-specific toggles into the plain build/validate commands `ami-builder`'s generic interface accepts.

---

# Architecture

```text
Caller
   |
   v
terraform-aws-ubuntu-ami
   |
   | translates enable_docker / enable_aws_cli / enable_python /
   | enable_predefined_packages / custom_build_commands into
   | component_build_commands / component_validate_commands
   |
   v
terraform-aws-ami-builder  <-- owns every AWS Image Builder resource
```

Prior to this design, `ubuntu-ami` duplicated all seven of `ami-builder`'s resources with Ubuntu-specific values hardcoded in. That meant any correctness fix or new AWS Image Builder capability had to be applied twice, in two repos, and the two inevitably drifted. This module now delegates entirely, so `ami-builder` is the only place Image Builder resource logic lives.

---

# Requirements

| Name         | Version              |
| ------------ | ---------------------- |
| Terraform    | `>= 1.6.0`             |
| AWS provider | `>= 6.0, < 7.0`        |

This module itself creates no AWS resources, so its own provider constraint is nominal; what actually matters is `ami-builder`'s constraint, inherited through the module call below.

---

# Usage

```hcl
module "ubuntu_ami" {
  source = "git::https://github.com/iamwonodi/terraform-aws-ubuntu-ami.git?ref=v2.0.0"

  project_name = "myapp"
  environment  = "production"

  parent_image = "ami-0abcdef1234567890"  # an existing Ubuntu 24.04 AMI

  enable_docker  = true
  enable_aws_cli = true

  instance_types         = ["t3.medium"]
  instance_profile_name = module.profile.instance_profile_name
  subnet_id               = module.vpc.build_subnet_id
  security_group_ids      = [module.build_sg.security_group_id]

  build_image = true
}
```

See `examples/complete` for a fuller example.

---

# Software Provisioning

## Predefined Packages

```hcl
enable_predefined_packages = true  # default
```

Installs: `git`, `jq`, `unzip`, `tar`, `gzip`, `curl`, `wget`, `nano`, `ca-certificates`, `gnupg`, `lsb-release`.

## Docker

```hcl
enable_docker = false  # default
```

Installs Docker Engine, Docker CLI, containerd, Docker Buildx, and Docker Compose from Docker's official Ubuntu repository (not Ubuntu's own distribution package), and adds the `ubuntu` user to the `docker` group.

## AWS CLI

```hcl
enable_aws_cli = false  # default
```

Installs AWS CLI v2 via the official AWS installer.

## Python

```hcl
enable_python = false  # default
```

Installs Python 3, `pip`, and `venv` support.

---

# Fixed Build Steps

These run unconditionally, regardless of any toggle above -- they're not optional software, they're baseline setup and verification for every AMI this module produces:

* **OS update** -- `apt-get update && apt-get upgrade`, always first.
* **`/opt` preparation** -- creates `/opt` with `755` permissions, for workload-specific installs that land on the AMI later.
* **Ubuntu identity validation** -- confirms `/etc/os-release` actually identifies the built AMI as Ubuntu, always the first validation step.

---

# Custom Commands

```hcl
custom_build_commands = [
  "curl -fsSL https://example.com/install.sh | bash"
]

custom_validate_commands = [
  "my-tool --version"
]
```

Run after everything above -- the module's fixed steps and any enabled software groups -- so custom commands can build on top of what's already installed.

---

# Pass-Through Fields

Everything `ami-builder` exposes for build infrastructure, logging, and distribution passes straight through this module unchanged: `key_pair`, `logging_s3_bucket_name` / `logging_s3_key_prefix`, `resource_tags`, `sns_topic_arn`, `placement_tenancy` / `placement_availability_zone`, `enhanced_image_metadata_enabled`, `root_volume_size`, `root_volume_type`, `component_version`, `recipe_version`, `enable_pipeline` and its related fields, and `build_image` / `build_trigger`. See the `ami-builder` README for what each does -- this module adds no opinion on top of any of them.

---

# Naming Multiple Instances

```hcl
image_name = "ubuntu"  # default
```

Passed straight through to `ami-builder`'s own `image_name`. Distinguishes this module's AWS resource names from any other `ami-builder`-based module (called directly, or through a different wrapper) sharing the same `project_name`/`environment` -- avoiding a resource-name collision.

---

# Versioning

This module follows Semantic Versioning.

Current release:

```text
v2.0.0
```

`v2.0.0` is a **major** release: this module no longer creates any `aws_imagebuilder_*` resource directly -- every one is now created by the `ami-builder` module it calls. For a fresh deployment this is transparent (the resulting AMI, component, and recipe behave identically). For an **existing deployment**, this is a genuine resource re-parenting: Terraform will plan to destroy the old locally-owned resources and create new ones inside the `ami-builder` module call, since they're tracked under entirely different resource addresses (`module.ami_builder.aws_imagebuilder_component.this` instead of `aws_imagebuilder_component.this` at this module's own root).

Before applying v2.0.0 against an existing deployment, migrate state -- note the source addresses use `.base`, this module's original resource labels, not `.this`:

```powershell
terraform state mv aws_imagebuilder_component.base 'module.ami_builder.aws_imagebuilder_component.this'
terraform state mv aws_imagebuilder_image_recipe.base 'module.ami_builder.aws_imagebuilder_image_recipe.this'
terraform state mv aws_imagebuilder_infrastructure_configuration.base 'module.ami_builder.aws_imagebuilder_infrastructure_configuration.this'
terraform state mv aws_imagebuilder_distribution_configuration.base 'module.ami_builder.aws_imagebuilder_distribution_configuration.this'
terraform state mv 'aws_imagebuilder_image.base[0]' 'module.ami_builder.aws_imagebuilder_image.this[0]'  # only if build_image = true
terraform state mv 'aws_imagebuilder_image_pipeline.base[0]' 'module.ami_builder.aws_imagebuilder_image_pipeline.this[0]'  # only if enable_pipeline = true
```

Then run `terraform plan` and confirm it shows no destroy/recreate actions before applying.

Consumers should pin the module to a released tag:

```hcl
source = "git::https://github.com/iamwonodi/terraform-aws-ubuntu-ami.git?ref=v2.0.0"
```

---

# License

This module is provided for reusable AWS infrastructure deployments and is intended to be consumed as a versioned Terraform module.
