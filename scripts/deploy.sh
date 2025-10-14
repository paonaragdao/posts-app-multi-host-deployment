#!//bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/4] Terraform init/apply…"
pushd "$ROOT_DIR/infra" >/dev/null
terraform init -input=false
terraform apply -auto-approve
EC2_IP=$(terraform output -raw public_ip)
popd >/dev/null

echo "[2/4] Write Ansible inventory…"
mkdir -p "$ROOT_DIR/ansible"
cat > "$ROOT_DIR/ansible/inventory.ini" <<INV
[posts]
$EC2_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/github_sdo_key
INV

echo "[3/4] Install Ansible collection…"
ansible-galaxy collection install community.docker >/dev/null

echo "[4/4] Run Ansible playbook…"
ansible-playbook -i "$ROOT_DIR/ansible/inventory.ini" "$ROOT_DIR/ansible/site.yml"

echo "✅ Deployment complete. Visit: http://$EC2_IP/"
