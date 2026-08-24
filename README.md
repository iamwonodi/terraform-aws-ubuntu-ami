# Terraform AWS Ubuntu AMI

Reusable Terraform module for building a standardized Ubuntu-based golden AMI using AWS EC2 Image Builder.

The module provides a reusable Ubuntu compute foundation while allowing the caller to decide which optional software should be installed.

The module does not contain workload-specific application configuration.

---

## Design

The module follows this boundary:

```text
                 Caller
                   │
                   │
        ┌──────────▼──────────┐
        │    Ubuntu AMI       │
        │      Module         │
        │                     │
        │ Ubuntu parent image │
        │ OS updates         │
        │ Optional packages  │
        │ Optional Docker    │
        │ Optional AWS CLI   │
        │ Optional Python    │
        │ Custom commands     │
        │ Validation          │
        └──────────┬──────────┘
                   │
                   ▼
             Golden Ubuntu AMI
                   │
          ┌────────┼────────┐
          ▼        ▼        ▼
       Compute   Database  Other
       Workload  Workload  Workload
```

The resulting AMI should contain only software and configuration that is appropriate for the workloads that will consume it.

---

# Software Provisioning

Optional software is controlled by boolean variables.

## Predefined Packages

Enable with:

```hcl
enable_predefined_packages = true
```

The module installs:

| Package           | Purpose                                     |
| ----------------- | ------------------------------------------- |
| `git`             | Source-control operations                   |
| `jq`              | JSON processing from shell scripts          |
| `unzip`           | Extract ZIP archives                        |
| `tar`             | Archive extraction and creation             |
| `gzip`            | Compression/decompression                   |
| `curl`            | HTTP/HTTPS requests and software downloads  |
| `wget`            | HTTP/HTTPS downloads                        |
| `nano`            | Terminal text editor                        |
| `ca-certificates` | Trusted CA certificates for TLS             |
| `gnupg`           | GPG signature and repository-key operations |
| `lsb-release`     | Linux distribution metadata                 |

These packages are installed only when:

```hcl
enable_predefined_packages = true
```

---

## Docker

Enable with:

```hcl
enable_docker = true
```

The module installs:

```text
Docker Engine
Docker CLI
containerd
Docker Buildx
Docker Compose
```

Docker is installed from Docker's official Ubuntu package repository.

The Ubuntu user is added to the `docker` group.

---

## AWS CLI

Enable with:

```hcl
enable_aws_cli = true
```

The module installs AWS CLI version 2.

The CLI is installed from the official AWS CLI distribution.

---

## Python

Enable with:

```hcl
enable_python = true
```

The module installs:

```text
python3
python3-pip
python3-venv
```

This provides Python execution, Python package installation, and isolated Python virtual environments.

Python is disabled by default because not every compute workload requires it.

---

# Fixed Build Steps

Some operations remain controlled by the module because they establish the minimum Ubuntu image lifecycle.

## Operating-System Update

The module performs:

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
```

This step is always executed.

It is not exposed as a caller-controlled switch because updating the operating system is part of creating the standardized image.

---

## `/opt` Directory

The module creates:

```text
/opt
```

with permissions:

```text
755
```

This step is always executed.

The directory provides a predictable location for software and platform files that may be installed by consuming workloads.

---

# Ubuntu Validation

The module always validates that the parent image is Ubuntu:

```bash
test -f /etc/os-release
grep -q 'Ubuntu' /etc/os-release
```

If this validation fails, Image Builder stops the build.

This prevents the Ubuntu-specific component from silently being applied to an incompatible operating system.

---

# Custom Build Commands

The caller can provide additional build commands:

```hcl
custom_build_commands = [
  "apt-get install -y htop",
  "mkdir -p /opt/my-platform"
]
```

These commands are added after the module-managed software installation steps.

Use this for software that is specific to the caller's platform but still belongs in the golden AMI.

Avoid placing application deployment, secrets, database data, or workload-specific runtime state inside the AMI.

---

# Custom Validation Commands

The caller can also provide validation commands:

```hcl
custom_validate_commands = [
  "htop --version",
  "test -d /opt/my-platform"
]
```

These commands execute during the Image Builder validation phase.

A failed validation command causes the AMI build to fail.

---

# Image Builder Resources

The module creates the following AWS resources.

## Image Builder Component

The component contains the build and validation commands.

```text
Component
   │
   ├── Fixed OS update
   ├── Optional predefined packages
   ├── Optional Docker
   ├── Optional AWS CLI
   ├── Optional Python
   ├── /opt preparation
   ├── Caller build commands
   └── Validation commands
```

---

## Image Recipe

The recipe defines:

```text
Parent Ubuntu image
        +
Image Builder component
        +
Root EBS configuration
        =
AMI definition
```

The recipe is versioned using:

```hcl
recipe_version = "1.0.0"
```

---

## Infrastructure Configuration

Image Builder temporarily launches an EC2 instance to construct the AMI.

The caller provides:

```hcl
instance_types
instance_profile_name
subnet_id
security_group_ids
```

The temporary build instance is used only during the image build.

It is not the EC2 instance that will run the final workload.

After the build completes, Image Builder terminates the temporary build instance.

---

## Distribution Configuration

The distribution configuration controls how the resulting AMI is registered and tagged.

The current module distributes the AMI into the AWS region selected by the Terraform provider.

It controls:

```text
AMI name
AMI description
AMI tags
AMI distribution region
```

---

# Immediate AMI Build

Use:

```hcl
build_image = true
```

to create an Image Builder image resource and immediately start a build.

Example:

```hcl
build_image   = true
build_trigger = "build-001"
```

A subsequent manual build can be requested by changing:

```hcl
build_trigger = "build-002"
```

The trigger is simply a Terraform change signal.

---

# Image Builder Pipeline

The pipeline is optional.

Enable it with:

```hcl
enable_pipeline = true
```

The default schedule is:

```hcl
pipeline_schedule = "cron(0 3 ? * SUN *)"
```

This means:

```text
Every Sunday
03:00 UTC
```

The pipeline allows AWS Image Builder to perform recurring image builds without Terraform needing to be executed every week.

The pipeline is useful when the organization wants the golden AMI periodically rebuilt from its current source configuration.

---

# Versioning

The module uses separate versions for the component and recipe.

## Component Version

```hcl
component_version = "1.0.0"
```

Increment this when the Image Builder component changes.

For example:

```text
1.0.0
1.0.1
1.1.0
2.0.0
```

---

## Recipe Version

```hcl
recipe_version = "1.0.0"
```

Increment this when the recipe definition changes.

Examples include:

```text
Parent image
Root volume size
Root volume type
Component configuration
Recipe configuration
```

---

# Recommended Build Workflow

For a component change:

```text
Modify component
      │
      ▼
Increment component_version
      │
      ▼
Increment recipe_version if recipe changed
      │
      ▼
terraform fmt -recursive
      │
      ▼
terraform validate
      │
      ▼
Change build_trigger when an immediate rebuild is required
      │
      ▼
terraform plan
      │
      ▼
terraform apply
```

Version numbers should represent actual configuration changes.

`build_trigger` should represent an intentional request to perform another build.

---

# Complete Example

```hcl
module "ubuntu_ami" {
  source = "git::https://github.com/iamwonodi/terraform-aws-ubuntu-ami.git?ref=v1.1.0"

  project_name = var.project_name
  environment  = var.environment

  parent_image = var.parent_image

  enable_predefined_packages = true
  enable_docker              = true
  enable_aws_cli             = true
  enable_python              = false

  custom_build_commands = [
    "mkdir -p /opt/platform"
  ]

  custom_validate_commands = [
    "test -d /opt/platform"
  ]

  component_version = "1.0.0"
  recipe_version    = "1.0.0"

  root_volume_size = 24
  root_volume_type = "gp3"

  instance_types        = ["t3.medium"]
  instance_profile_name = var.instance_profile_name
  subnet_id             = var.subnet_id
  security_group_ids    = var.security_group_ids

  build_image   = true
  build_trigger = "build-001"

  enable_pipeline            = false
  pipeline_schedule          = "cron(0 3 ? * SUN *)"
  enable_image_tests         = true
  image_test_timeout_minutes = 60

  tags = {
    Project   = "blueprints"
    ManagedBy = "Terraform"
  }
}
```

---

# Responsibility Boundary

## Ubuntu AMI Module

Responsible for:

```text
Ubuntu foundation
OS updates
Predefined utilities
Optional Docker
Optional AWS CLI
Optional Python
/opt preparation
Caller-provided AMI build commands
Caller-provided validation commands
Image Builder component
Image Builder recipe
Build infrastructure
AMI distribution
Optional Image Builder pipeline
AMI testing
```

## Calling Module

Responsible for:

```text
VPC
Subnets
Security groups
IAM
Parent AMI selection
AMI release decisions
Workload configuration
Application deployment
Secrets
Databases
Persistent data
```

---


Consumers should reference an immutable release tag:

```hcl
source = "git::https://github.com/iamwonodi/terraform-aws-ubuntu-ami.git?ref=v1.1.0"
```

---

# Module Structure

```text
terraform-aws-ubuntu-ami/
│
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── data.tf
├── versions.tf
├── README.md
├── .gitignore
│
└── examples/
    └── complete/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

The important architectural change is that **the module now provides controlled building blocks rather than forcing every caller to install the same software**.

For example:

```text
enable_predefined_packages = true
enable_docker              = false
enable_aws_cli             = true
enable_python              = true
```

gives the caller a predictable Ubuntu image containing exactly those optional software groups plus the module's fixed foundation steps.
