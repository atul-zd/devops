# 🚀 Deploy Amazon EKS Cluster Using Terraform & Access via kubectl

This guide provides step-by-step instructions to:

- Install required tools (AWS CLI, Terraform, kubectl)
- Configure AWS credentials
- Create an EKS cluster using Terraform
- Access the Kubernetes cluster using `kubectl`

---

## 🧰 Prerequisites

- An AWS account
- IAM user with permissions for EKS, VPC, EC2, IAM, etc.
- Ubuntu/Debian-based system (for the install commands below)



```bash
# ------------------------------------------
# 1. Install AWS CLI
# ------------------------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# ------------------------------------------
# 2. Configure AWS credentials
# ------------------------------------------
aws configure 

# ------------------------------------------
# 3. Install Terraform
# ------------------------------------------
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl unzip
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y
terraform -version

# ------------------------------------------
# 4. Initialize and Apply Terraform Code
# ------------------------------------------
cd /path/to/your/terraform/code

terraform init
terraform plan
terraform apply -auto-approve

# ------------------------------------------
# 5. Install kubectl
# ------------------------------------------
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# ------------------------------------------
# 6. Access the EKS Cluster via kubectl
# ------------------------------------------

# Update kubeconfig

aws eks update-kubeconfig --region <aws-region> --name <cluster-name>

#aws eks update-kubeconfig --region ap-south-1 --name my-eks-cluster

# Check cluster access
kubectl get nodes



# ------------------------------------------
# 7. (Optional) Destroy the Infrastructure
# ------------------------------------------
terraform destroy -auto-approve

