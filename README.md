# Posts App Multi-Host Deployment
## COSC2759 Assignment 2 - Semester 2, 2025
**Student Name:** Paolo Miguel Naragdao
**Student Number:** s3939218

Automated full deployment of a **Posts Application** to multiple AWS EC2 instances behind Application Load Balancers to distribute Backend and Frontend requests; using **Terraform** and **Ansible**, through a **GitHub Actions** CI/CD Pipeline that handles automatic provisioning and configuration on every push made to the 'main' branch.


## Deployment Summary
| Service       | Container Image                       | Port Mapping  | Host Purpose                    |
|---------------|---------------------------------------|---------------|---------------------------------|
| Database      | `rmitdominichynes/sdo-2025:db`        | 5432          | `posts-db`       → PostgreSQL   |
| Backend       | `rmitdominichynes/sdo-2025:backend`   | 80   → 3000   | `posts-backend`  → Node API     |
| Frontend      | `rmitdominichynes/sdo-2025:frontend`  | 8081 → 80     | `posts-frontend` → React UI     |

### Terraform
- Provisions the following Instances in the default VPC:
    - 1 x DB Host
    - 2 x Backend Hosts  | ALB
    - 2 x Frontend Hosts | ALB
- Creates Security Groups per service and ALBs
- Stores Terraform state remotely in an S3 Bucket
- Outputs ALB Public DNS names

### Ansible
- Installs Docker and Python SDK on hosts
- Runs the three Container Image with its required environment variables on each EC2 Instance

### Scripts
**deploy.sh** overview:

1. Run 'terraform apply'
2. Generate 'inventory.ini' containing host IPs
3. Install 'community.docker'
4. Run 'ansible/site.yml'

### GitHub Actions CI/CD Workflow
'.github/workflows/deploy.yml'

1. Configure AWS Credentials form GitHub Repo Secrets
2. Write SSH key from ssh_private_key secret to runner
3. Runs Terraform Init & Apply
4. Builds 'inventory.ini'
5. Executes ansible


