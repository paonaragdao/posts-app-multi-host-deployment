#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${KEY_PATH:-$HOME/.ssh/github_sdo_key}"

echo "[1/5] Terraform init / apply"
pushd "$ROOT_DIR/infra" >/dev/null
terraform init -input=false
terraform apply -auto-approve -input=false

DB_IP=$(terraform output -raw db_ip)
BACKEND_ALB=$(terraform output -raw backend_alb_dns)
FRONTEND_ALB=$(terraform output -raw frontend_alb_dns)

BE_A=$(terraform output -raw backend_a_ip)
BE_B=$(terraform output -raw backend_b_ip)
FE_A=$(terraform output -raw frontend_a_ip)
FE_B=$(terraform output -raw frontend_b_ip)
popd >/dev/null

echo "[2/5] Writing Ansible inventory"
mkdir -p "$ROOT_DIR/ansible"
cat > "$ROOT_DIR/ansible/inventory.ini" <<INV
[db]
$DB_IP ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH

[backend]
$BE_A ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH db_host=$DB_IP
$BE_B ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH db_host=$DB_IP

[frontend]
$FE_A ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH backend_host=$BACKEND_ALB
$FE_B ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH backend_host=$BACKEND_ALB
INV


echo "[3/5] Ensuring Ansible Docker collection"
ansible-galaxy collection install community.docker >/dev/null

echo "[4/5] Running Ansible playbook"
ansible-playbook -i "$ROOT_DIR/ansible/inventory.ini" "$ROOT_DIR/ansible/site.yml"

echo "[5/5] Done."
echo "DB Host:        $DB_IP:5432"
echo "Backend (ALB):  http://$BACKEND_ALB/"
echo "Frontend (ALB): http://$FRONTEND_ALB/"



