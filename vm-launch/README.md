# Azure Infrastructure with Terraform

A hands-on infrastructure-as-code project that provisions an Ubuntu Linux virtual machine and its supporting network on Microsoft Azure. It demonstrates repeatable provisioning, parameterized configuration, SSH key authentication, and disciplined Git practices.

**Stack:** Terraform · AzureRM `~> 5.0` · Ubuntu 24.04 LTS · Azure Canada Central

## Architecture

| Component | Configuration |
| --- | --- |
| Workload resource group | `rg-terraform-demo` in `canadacentral` |
| Additional resource group | `rg-state-demo`, reserved for future state infrastructure |
| Virtual network | `10.0.0.0/16` |
| Subnet | `10.0.1.0/24` |
| Public IP | Static allocation |
| Network security group | Inbound SSH on TCP port `22` |
| Network interface | Dynamic private IP and attached public IP |
| Linux VM | Ubuntu 24.04 LTS, `Standard_B2s`, SSH key authentication |

SSH traffic reaches the VM through its public IP and network interface, subject to the NSG rules. The VM resides inside the subnet and virtual network.

This is a learning deployment. State is currently local; creating `rg-state-demo` does not configure a remote backend.

## Repository structure

```text
azure/
├── README.md
├── .gitignore
└── vm-launch/
    ├── vm.tf                      # Provider, resources, and outputs
    ├── variables.tf               # Input variable declarations
    ├── terraform.tfvars.example   # Placeholder template; create below
    ├── terraform.tfvars           # Local values; ignored by Git
    └── .terraform.lock.hcl        # Committed provider dependency lock file
```

Terraform creates `.terraform/` and local state files during use. These are excluded from version control.

## Prerequisites

- Terraform CLI compatible with the AzureRM 5.x provider.
- Azure CLI and an Azure subscription with permission to create the resources above.
- Available quota for `Standard_B2s` in `canadacentral`.
- An SSH key pair. Configure the VM's admin username and public key reference in `vm.tf` to match your setup; keep the private key on your machine.

## Getting started

### 1. Authenticate

From the repository root (`azure/`):

```bash
az login
az account set --subscription "<your-subscription-id>"
cd vm-launch
```

The provider's `subscription_id` is supplied through `variables.tf` and your local variable values. Use the same subscription selected in Azure CLI. See [Azure CLI sign-in guidance](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively).

### 2. Set local variables

Create `vm-launch/terraform.tfvars.example` with this placeholder and commit the example so others can reproduce the setup:

```hcl
subscription_id = "<your-subscription-id>"
```

From `vm-launch/`, copy it to your local configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Replace the placeholder in `terraform.tfvars` with your subscription ID. Terraform [automatically loads this file](https://developer.hashicorp.com/terraform/language/values/variables). Keep it out of Git. The subscription ID identifies the deployment target; authentication comes from your Azure login.

Review `vm.tf` before deploying, particularly the SSH public key, admin username, and NSG source address.

### 3. Validate and deploy

Run all Terraform commands from `vm-launch/`:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the proposed resources and confirm the apply when ready. Azure resources incur charges while provisioned.

### 4. Connect

```bash
terraform output
```

The configuration exposes the VM's public IP address and an SSH command. Use the displayed command with the private key corresponding to the configured public key. If that key is not in a default location or loaded into your SSH agent, specify it with `ssh -i <private-key-path>`.

### 5. Clean up

```bash
terraform plan -destroy
terraform destroy
```

Review and confirm deletion when the lab is complete. This removes resources managed by this configuration, including both resource groups. Retain the local state until cleanup finishes.

## Security and version control

- **Ignore local configuration:** `terraform.tfvars` stays local; the example contains placeholders only.
- **Protect state:** ignore `*.tfstate` and `*.tfstate.*`. State can contain sensitive values; protect local copies and any saved plan files.
- **Ignore downloaded providers:** exclude `.terraform/` from Git.
- **Commit the lock file:** keep `.terraform.lock.hcl` for consistent provider selection and checksum verification. See [Terraform's dependency lock file guidance](https://developer.hashicorp.com/terraform/language/files/dependency-lock).
- **Keep credentials out of Git:** never commit private SSH keys, cloud credentials, access tokens, or secrets.
- **Limit SSH exposure:** review the NSG source range and restrict TCP/22 to your trusted public IP (`/32`) before exposing the VM. SSH key authentication alone does not restrict network access.

Ignore rules do not remove files already staged or tracked. Review `git status` and the staged diff before committing.

## Learning goals

- Define Azure compute and networking resources declaratively.
- Understand dependencies between VNets, subnets, NICs, public IPs, and VMs.
- Separate environment-specific inputs from infrastructure code.
- Practice the Terraform initialization, validation, planning, deployment, and cleanup lifecycle.
- Use outputs to make deployed infrastructure easier to access.
- Maintain a reproducible repository without committing local state or credentials.

## Future improvements

- Configure an Azure Storage remote state backend with access controls and state locking; manage backend infrastructure separately from the VM lifecycle.
- Parameterize the NSG source IP and restrict SSH to a trusted address.
- Expand variables for naming, region, VM size, and SSH configuration.
- Add consistent resource tags, reusable modules, and CI checks for formatting and validation.
- Explore Azure Bastion or private connectivity to reduce public SSH exposure.
