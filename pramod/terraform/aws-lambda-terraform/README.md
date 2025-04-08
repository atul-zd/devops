--- 

### Prerequisite:
1. **AWS CLI** installed and configured
2. **Terraform** installed

### How to Run This Terraform Code:

1. **Download and configure AWS CLI**:
   - Follow the [AWS CLI documentation](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) to install and configure AWS CLI on your machine.

2. **Download Terraform**:
   - Install Terraform from the [Terraform website](https://www.terraform.io/downloads.html) and follow the instructions to set it up.

### Running the Terraform Code:

1. **Navigate to the Terraform directory**:
   ```bash
   cd terraform/
   ```

2. **Initialize the Terraform configuration**:
   ```bash
   terraform init
   ```

3. **Validate the configuration**:
   ```bash
   terraform validate
   ```

4. **Apply the Terraform configuration**:
   ```bash
   terraform apply
   ```
   - You will be prompted to confirm by typing **yes** to create the infrastructure.

### Destroying the Terraform Infrastructure:

1. **Run the destroy command**:
   ```bash
   terraform destroy
   ```
   - You will be prompted to confirm by typing **yes** to destroy the infrastructure.

--- 


