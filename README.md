# Terraform AWS Ubuntu AMI

Reusable Terraform module for building a standardized **Ubuntu-based golden AMI** using AWS EC2 Image Builder.

The module is intended to provide a common operating-system and compute foundation for platform workloads. Workload-specific configuration, application code, secrets, database configuration, and application bootstrap logic remain outside this module.

---

## Architecture

```text
                         ┌──────────────────────────┐
                         │       Caller Module      │
                         │                          │
                         │ project / environment    │
                         │ VPC / subnet / SG        │
                         │ IAM instance profile     │
                         │ Ubuntu parent AMI        │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────┐
                    │       Ubuntu AMI Module         │
                    │                                 │
                    │  Image Builder Component       │
                    │  Image Builder Recipe          │
                    │  Infrastructure Configuration  │
                    │  Distribution Configuration    │
                    │  Optional Image Pipeline        │
                    └───────────────┬─────────────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────────┐
                    │ Temporary Image Builder EC2     │
                    │                                 │
                    │ Ubuntu parent image             │
                    │ + base packages                 │
                    │ + Docker                        │
                    │ + AWS CLI                       │
                    │ + common directories             │
                    └───────────────┬─────────────────┘
                                    │
                              AMI build
                                    │
                                    ▼
                    ┌─────────────────────────────────┐
                    │       Golden Ubuntu AMI         │
                    │                                 │
                    │ Reusable compute foundation     │
                    └───────────────┬─────────────────┘
                                    │
                  ┌─────────────────┼──────────────────┐
                  ▼                 ▼                  ▼
             Compute Module    Database Module    Other Workloads
```

---

## What This Module Provides

The module creates the AWS Image Builder resources required to produce a reusable Ubuntu AMI.

The resulting AMI provides a standardized compute foundation containing software that is common across workloads.

Typical software installed by the component includes:

* Git
* jq
* unzip
* tar
* gzip
* curl
* wget
* nano
* Docker
* AWS CLI
* common compute directories

The exact software installed is controlled by the Image Builder component defined by this module.

---

## What This Module Does Not Provide

This module intentionally does **not** manage workload-specific resources or configuration.

The module does not provide:

* EC2 application instances
* application source code
* application containers
* database configuration
* database credentials
* application secrets
* workload-specific bootstrap scripts
* EBS data volumes
* VPCs
* subnets
* security groups
* IAM roles or instance profiles

Those responsibilities belong to the consuming/calling module.

This keeps the AMI reusable across different workloads.

---

# Image Builder Architecture

The module uses several AWS Image Builder resources.

## 1. Image Builder Component

The component defines the commands executed during the AMI build.

It is responsible for installing and configuring software that should exist on every compute host using this AMI.

For example:

```text
Ubuntu
  │
  ├── Update operating system
  ├── Install common utilities
  ├── Install Docker
  ├── Install AWS CLI
  └── Prepare common directories
```

---

## 2. Image Recipe

The recipe defines how the final AMI is assembled.

It specifies:

* parent Ubuntu image
* Image Builder component
* root EBS volume configuration
* recipe version

The recipe is the versioned definition of the AMI.

Changing the recipe version creates a new Image Builder recipe version.

---

## 3. Infrastructure Configuration

Image Builder temporarily launches an EC2 instance to construct and test the AMI.

That temporary instance uses:

* an instance profile supplied by the caller
* a subnet supplied by the caller
* security groups supplied by the caller
* the configured instance type

The temporary instance exists only for the AMI build process.

After the build completes, Image Builder terminates the temporary build instance.

The temporary build instance is **not** the compute instance that your workloads will eventually run on.

---

## 4. Distribution Configuration

The distribution configuration controls how the resulting AMI is named, tagged, and distributed.

This module currently distributes the resulting AMI in the AWS region in which the module is executed.

The resulting AMI receives tags identifying:

* project
* environment
* AMI name
* AMI version
* resource type
* Terraform management

The distribution configuration is separate from the temporary build infrastructure because:

```text
Build infrastructure
        │
        │ creates the AMI
        ▼
Golden AMI
        │
        │ distribution configuration
        ▼
Available AMI
```

---

# Image Builder Pipeline

The Image Builder pipeline is optional.

Set:

```hcl
enable_pipeline = true
```

to create it.

The pipeline provides recurring automated AMI builds according to:

```hcl
pipeline_schedule = "cron(0 3 ? * SUN *)"
```

The default schedule means:

```text
Every Sunday
at 03:00 UTC
```

Because AWS Image Builder schedules operate in UTC, the corresponding local time depends on the AWS region/time zone you are operating from.

The pipeline is useful when you want the golden AMI to be periodically rebuilt from the current parent image and current component/recipe definitions.

For example:

```text
Sunday 03:00 UTC
       │
       ▼
Image Builder pipeline
       │
       ▼
Current Ubuntu parent image
       +
Current component
       +
Current recipe
       │
       ▼
New golden AMI
```

The pipeline does not mean that an AMI is rebuilt continuously whenever Terraform changes.

Terraform manages the pipeline configuration, while AWS Image Builder executes the scheduled pipeline.

---

# Manual AMI Builds

The module also supports an explicit Terraform-controlled build trigger.

The recommended implementation uses:

```hcl
resource "terraform_data" "build_trigger" {
  input = var.build_trigger
}
```

and the Image Builder image resource uses:

```hcl
lifecycle {
  replace_triggered_by = [
    terraform_data.build_trigger
  ]
}
```

This allows the caller to request a new AMI build by changing the value of:

```hcl
build_trigger
```

For example:

```hcl
build_image   = true
build_trigger = "2026-08-24-build-001"
```

After a successful build, a subsequent manual build can be requested by changing the trigger:

```hcl
build_image   = true
build_trigger = "2026-08-24-build-002"
```

The trigger value itself has no semantic meaning to AWS. It is simply a Terraform change signal.

The workflow is:

```text
Change build_trigger
        │
        ▼
terraform plan
        │
        ▼
terraform_data.build_trigger changes
        │
        ▼
aws_imagebuilder_image replacement
        │
        ▼
Image Builder starts a new AMI build
```

Changing the trigger should therefore be intentional.

---

# Immediate Build vs Pipeline

The module supports two different build mechanisms.

## Immediate Terraform Build

Use:

```hcl
build_image = true
```

when the module should create an Image Builder image resource and perform a build immediately through Terraform.

This is useful when:

* creating the AMI for the first time
* testing component changes
* manually producing a new AMI
* validating a new parent image

---

## Scheduled Pipeline

Use:

```hcl
enable_pipeline = true
```

when recurring automated builds are required.

For example:

```hcl
enable_pipeline   = true
pipeline_schedule = "cron(0 3 ? * SUN *)"
```

The pipeline then operates independently according to its configured schedule.

---

# Build Trigger Rules

The `build_trigger` variable should be used when an explicit Terraform-controlled rebuild is required.

Example:

```hcl
build_trigger = "2026-08-24-build-001"
```

After changing the AMI component:

```hcl
build_trigger = "2026-08-24-build-002"
```

run:

```powershell
terraform plan
terraform apply
```

Do not repeatedly change `build_trigger` without intending to create another AMI build.

---

# Versioning

The module has separate versions for the Image Builder component and recipe.

## Component Version

```hcl
component_version = "1.0.0"
```

The component version identifies the version of the software installation/configuration component.

When changing the component definition, increment this version.

Example:

```hcl
component_version = "1.0.1"
```

---

## Recipe Version

```hcl
recipe_version = "1.0.0"
```

The recipe version identifies the Image Builder recipe.

Increment this version when changing the recipe definition, including changes to things such as:

* parent image
* root volume configuration
* components
* recipe configuration

Example:

```hcl
recipe_version = "1.0.1"
```

---

# Recommended Versioning Workflow

When modifying the component:

```text
Modify component
      │
      ▼
Increment component_version
      │
      ▼
Test AMI build
      │
      ▼
Update recipe if required
      │
      ▼
Increment recipe_version when recipe changes
```

When changing the parent Ubuntu AMI:

```text
Change parent_image
      │
      ▼
Increment recipe_version
      │
      ▼
Build new AMI
```

For an explicit manual build regardless of version changes:

```text
Change build_trigger
      │
      ▼
terraform apply
      │
      ▼
New AMI build
```

Version numbers should therefore represent actual configuration changes, while `build_trigger` represents an intentional build request.

---

# Important Terraform Behaviour

Changing the Image Builder component does not mean Terraform automatically creates a new AMI merely because the component file changed.

Terraform evaluates the resource configuration.

For predictable AMI releases:

1. Modify the component.
2. Increment `component_version`.
3. Increment `recipe_version` if the recipe itself changed.
4. Use `build_trigger` when an explicit manual build is required.
5. Run:

```powershell
terraform plan
terraform apply
```

---

# Ubuntu Parent Image

The caller supplies the Ubuntu parent image through:

```hcl
parent_image = var.parent_image
```

The module does not hard-code an Ubuntu AMI ID.

This is intentional because AMI IDs are region-specific and change over time.

A caller can therefore supply the appropriate Ubuntu AMI for its AWS region.

Example:

```hcl
parent_image = "ami-xxxxxxxxxxxxxxxxx"
```

The supplied AMI should be a compatible Ubuntu image for the target AWS region.

For production usage, the caller should maintain an explicit and controlled parent-image selection strategy rather than blindly changing the AMI on every deployment.

---

# Required Build Infrastructure

The caller must provide an IAM instance profile:

```hcl
instance_profile_name = var.instance_profile_name
```

The profile is attached to the temporary Image Builder build instance.

The caller must also provide:

```hcl
subnet_id = var.subnet_id

security_group_ids = var.security_group_ids
```

The subnet must provide the temporary Image Builder instance with the network access required to:

* retrieve the Ubuntu image/build dependencies
* retrieve package repositories
* download required software
* communicate with AWS services used during the build

If the subnet does not have direct internet access, the caller must provide the required private connectivity, such as suitable VPC endpoints and/or NAT connectivity.

---

# Public IP Address

The module does not require the temporary Image Builder instance to have a public IP address.

The caller controls:

```hcl
associate_public_ip_address = false
```

or the corresponding infrastructure configuration according to the module implementation.

A private subnet can therefore be used when the VPC provides the necessary outbound connectivity.

---

# Image Testing

Image Builder testing is enabled by default:

```hcl
enable_image_tests = true
```

The test timeout is:

```hcl
image_test_timeout_minutes = 60
```

Image Builder can perform its built-in image validation after the AMI is created.

Keeping image tests enabled is recommended for a reusable golden AMI.

---

# Example Module Usage

A consuming module can configure the AMI module like this:

```hcl
module "ubuntu_ami" {
  source = "git::https://github.com/iamwonodi/terraform-aws-ubuntu-ami.git?ref=v1.0.0"

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
```

---

# Example Terraform Variables

```hcl
project_name = "blueprints"
environment  = "development"

parent_image = "ami-xxxxxxxxxxxxxxxxx"

component_version = "1.0.0"
recipe_version    = "1.0.0"

root_volume_size = 24
root_volume_type = "gp3"

instance_types        = ["t3.medium"]
instance_profile_name = "image-builder-profile"

subnet_id = "subnet-xxxxxxxxxxxxxxxxx"

security_group_ids = [
  "sg-xxxxxxxxxxxxxxxxx"
]

build_image   = true
build_trigger = "2026-08-24-build-001"

enable_pipeline            = false
pipeline_schedule          = "cron(0 3 ? * SUN *)"
enable_image_tests         = true
image_test_timeout_minutes = 60

tags = {
  ManagedBy = "Terraform"
  Project   = "blueprints"
}
```

---

# Scheduled Production Configuration

A production-oriented configuration could instead use the pipeline:

```hcl
build_image   = false
build_trigger = ""

enable_pipeline   = true
pipeline_schedule = "cron(0 3 ? * SUN *)"

enable_image_tests         = true
image_test_timeout_minutes = 60
```

This allows AWS Image Builder to perform recurring builds without Terraform having to run every week.

---

# Manual Development Configuration

For development and testing:

```hcl
build_image   = true
build_trigger = "2026-08-24-build-001"

enable_pipeline = false
```

When another build is required:

```hcl
build_trigger = "2026-08-24-build-002"
```

Then:

```powershell
terraform plan
terraform apply
```

---

# AMI Lifecycle

The AMI produced by this module is intended to become the base image for other compute modules.

A typical platform workflow is:

```text
Ubuntu Parent AMI
       │
       ▼
ubuntu-ami module
       │
       ▼
Golden Ubuntu AMI
       │
       ├──────────────► Compute workloads
       │
       ├──────────────► Database compute
       │
       └──────────────► Other platform hosts
```

Workload-specific modules can then start EC2 instances from the resulting AMI.

This separates:

```text
Operating-system foundation
```

from:

```text
Workload configuration
```

which keeps the AMI reusable.

---

# Recommended Responsibilities

## Ubuntu AMI Module

Responsible for:

* Ubuntu base image
* operating-system updates
* common utilities
* Docker
* AWS CLI
* common directories
* Image Builder component
* Image Builder recipe
* Image Builder build infrastructure
* AMI distribution
* optional image pipeline
* AMI testing

## Calling Module

Responsible for:

* VPC
* subnet
* security groups
* IAM instance profile
* parent AMI selection
* build trigger
* AMI release/version decisions
* workload-specific configuration
* application configuration
* secrets
* databases
* persistent data volumes

---

# Outputs

The module exposes the following outputs.

| Output                             | Description                                                 |
| ---------------------------------- | ----------------------------------------------------------- |
| `component_arn`                    | ARN of the Image Builder component                          |
| `recipe_arn`                       | ARN of the Image Builder recipe                             |
| `infrastructure_configuration_arn` | ARN of the Image Builder build infrastructure configuration |
| `distribution_configuration_arn`   | ARN of the Image Builder distribution configuration         |
| `ami_id`                           | ID of the AMI produced by the build                         |
| `image_arn`                        | ARN of the Image Builder image                              |
| `pipeline_arn`                     | ARN of the Image Builder pipeline when enabled              |

`ami_id`, `image_arn`, and `pipeline_arn` can be `null` when their corresponding functionality is disabled.

---

# Terraform Workflow

Initialize the module:

```powershell
terraform init
```

Format the module:

```powershell
terraform fmt -recursive
```

Validate the configuration:

```powershell
terraform validate
```

Review changes:

```powershell
terraform plan
```

Apply the configuration:

```powershell
terraform apply
```

---

# Recommended Release Workflow

For a normal AMI component update:

```text
1. Modify the Image Builder component
2. Increment component_version
3. Increment recipe_version when the recipe changes
4. Run terraform fmt -recursive
5. Run terraform validate
6. Run terraform plan
7. Run terraform apply
8. Validate the resulting AMI
9. Tag the module release
```

For an explicit manual rebuild:

```text
1. Keep the component/recipe versions unchanged if no configuration changed
2. Change build_trigger
3. Run terraform plan
4. Confirm the Image Builder image will be replaced
5. Run terraform apply
6. Validate the resulting AMI
```

---

# Git Release Example

After validating the module:

```powershell
git add .
git commit -m "feat: add reusable Ubuntu AMI module"
git push origin main
```

Create a release tag:

```powershell
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

Consumers can then reference the immutable release:

```hcl
module "ubuntu_ami" {
  source = "git::https://github.com/iamwonodi/terraform-aws-ubuntu-ami.git?ref=v1.0.0"

  # configuration...
}
```

Using a release tag rather than a moving branch keeps consuming Terraform configurations reproducible.

---

# Design Principle

This module intentionally follows a simple boundary:

```text
                    Ubuntu AMI
                         │
          ┌──────────────┴──────────────┐
          │                             │
     Common compute                 Workload
      foundation                   configuration
          │                             │
          ▼                             ▼
   ubuntu-ami module              Caller module
```

The AMI should contain only what is genuinely common to the platform.

Anything that is specific to a database, API, frontend, worker, or other workload should remain outside the AMI and be supplied by the consuming module.

This allows the same golden Ubuntu AMI to be reused across multiple compute workloads without coupling the base image to a particular application.
