#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <ALB_DNS_NAME>"
  exit 1
fi

ALB_DNS_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo yum install -y httpd-tools || sudo dnf install -y httpd-tools

echo "Prueba de lectura sobre backend EC2"
ab -n 1000 -c 100 "http://${ALB_DNS_NAME}/admin/enrollments"

echo
echo "Prueba de escritura hacia Lambda via ALB"
ab -p "${SCRIPT_DIR}/payload.json" -T application/json -n 150 -c 20 "http://${ALB_DNS_NAME}/api/confirm"
