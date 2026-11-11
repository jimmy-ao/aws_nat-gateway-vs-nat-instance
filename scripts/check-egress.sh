#!/usr/bin/env bash
# Ask each test instance which public IP it egresses from, using SSM Run Command,
# and compare it with the IP of the NAT its subnet is supposed to use.
# Run from anywhere after `terraform apply`. Requires: aws CLI v2, jq.
# The names below are the keys of local.test_subnets in test-instances.tf: rename one, rename both.
# Works with the bash 3.2 that ships with macOS.
set -euo pipefail

cd "$(dirname "$0")/.."

ids_json=$(terraform output -json test_instance_ids)
gw_ip=$(terraform output -raw nat_gateway_public_ip)
inst_ip=$(terraform output -raw nat_instance_public_ip)
rnat_ips=$(terraform output -json regional_nat_gateway_public_ips | jq -r '[.[]] | join(",")')

expected_for() {
  case "$1" in
    via-zonal-nat-gateway) echo "$gw_ip" ;;
    via-nat-instance) echo "$inst_ip" ;;
    via-regional-nat) echo "${rnat_ips:-pending}" ;;
  esac
}

row() { printf '%-22s %-16s %-16s %s\n' "$@"; }

status=0
row "SUBNET" "EGRESS IP" "EXPECTED" "RESULT"
for name in via-zonal-nat-gateway via-nat-instance via-regional-nat; do
  id=$(jq -r --arg k "$name" '.[$k]' <<<"$ids_json")
  exp=$(expected_for "$name")

  # An instance whose NAT is broken never registers with SSM, so the command cannot even be sent.
  if ! cmd_id=$(aws ssm send-command \
    --instance-ids "$id" \
    --document-name AWS-RunShellScript \
    --parameters 'commands=["curl -s --max-time 10 https://checkip.amazonaws.com"]' \
    --query Command.CommandId --output text 2>/dev/null); then
    row "$name" "none" "$exp" "UNREACHABLE (not in SSM: is its NAT working?)"
    status=1
    continue
  fi

  # The waiter gives up after about 100 seconds and exits non-zero on failure; we still want the output.
  aws ssm wait command-executed --command-id "$cmd_id" --instance-id "$id" 2>/dev/null || true

  ip=$(aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$id" \
    --query StandardOutputContent --output text | tr -d '[:space:]')

  if [[ -n "$ip" && ",$exp," == *",$ip,"* ]]; then
    result=OK
  else
    result=MISMATCH
    status=1
  fi
  row "$name" "${ip:-none}" "$exp" "$result"
done

exit "$status"
