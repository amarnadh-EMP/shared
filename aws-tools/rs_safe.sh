#!/usr/bin/env bash
# Guarded Redshift runner (dev cluster only).
# Usage: rs_safe.sh <iam|etl> "<sql>" [--allow-write]
# Default is READ-ONLY. Destructive SQL is always refused here; it must be run by hand
# only after the owner explicitly approves that exact statement. Needs a valid `dev` SSO login.
set -euo pipefail
AUTH=${1:?auth: iam|etl}; SQL=${2:?sql}; FLAG=${3:-}
BIN="${AWS_TOOLS_DIR:-$HOME/.local/aws-cli-v2}/bin/aws"
CLUSTER=capsa-edm-dev; REGION=us-east-2; DB=dev; PROFILE=dev

UP=$(echo "$SQL" | tr '[:lower:]' '[:upper:]' | tr '\n' ' ')
# 1) Always refuse destructive / privilege / structural statements
if echo "$UP" | grep -Eq '(^|;|[[:space:]])(DROP|TRUNCATE|DELETE|ALTER|GRANT|REVOKE|VACUUM|UNLOAD|COPY|CALL)[[:space:]]'; then
  echo "REFUSED: destructive/structural statement. Needs explicit owner confirmation and a manual run."; exit 3
fi
# 2) One statement at a time
[ "$(echo "$SQL" | tr -cd ';' | wc -c)" -gt 1 ] && { echo "REFUSED: multiple statements"; exit 3; }
# 3) Writes only with --allow-write; UPDATE needs a WHERE
if echo "$UP" | grep -Eq '(^|[[:space:]])(INSERT|UPDATE|CREATE|MERGE)[[:space:]]'; then
  [ "$FLAG" = "--allow-write" ] || { echo "REFUSED: write statement without --allow-write"; exit 3; }
  if echo "$UP" | grep -Eq '^[[:space:]]*UPDATE' && ! echo "$UP" | grep -q ' WHERE '; then
    echo "REFUSED: UPDATE without WHERE"; exit 3
  fi
fi

AWSX=(env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY "$BIN" --profile "$PROFILE" --region "$REGION")
CRED=()
if [ "$AUTH" = etl ]; then
  # Only the ARN is passed; the secret value is never read or printed.
  ARN=$("${AWSX[@]}" secretsmanager describe-secret --secret-id dev/capsa_edm_etl_user/redshift --query ARN --output text)
  CRED=(--secret-arn "$ARN")
fi

echo ">> [dev/$AUTH] $SQL" >&2
id=$("${AWSX[@]}" redshift-data execute-statement --cluster-identifier "$CLUSTER" --database "$DB" "${CRED[@]}" --sql "$SQL" --query Id --output text)
for _ in $(seq 1 30); do
  s=$("${AWSX[@]}" redshift-data describe-statement --id "$id" --query '[Status,Error]' --output text)
  case "$s" in FINISHED*) break;; FAILED*|ABORTED*) echo "$s"; exit 1;; esac; sleep 2
done
"${AWSX[@]}" redshift-data get-statement-result --id "$id" --output json 2>/dev/null | python3 -c "
import json,sys
try:
  for r in json.load(sys.stdin)['Records']: print(' | '.join(str(list(c.values())[0]) for c in r))
except Exception: print('OK')"
