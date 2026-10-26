#!/usr/bin/env bash
# One-time-per-container setup: installs AWS CLI v2 and writes the Capsa SSO config.
# Safe to re-run. Contains no secrets. Does NOT log in; the owner approves the SSO login from their phone.
set -euo pipefail

PREFIX="${AWS_TOOLS_DIR:-$HOME/.local/aws-cli-v2}"
BIN="$PREFIX/bin/aws"

if [ ! -x "$BIN" ]; then
  tmp=$(mktemp -d)
  curl -sSfL -o "$tmp/awscliv2.zip" https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  "$tmp/aws/install" --update -i "$PREFIX/inst" -b "$PREFIX/bin"
  rm -rf "$tmp"
fi

mkdir -p "$HOME/.aws"
CFG="$HOME/.aws/config"
touch "$CFG"
if ! grep -q '^\[sso-session capsa\]' "$CFG"; then
  cat >> "$CFG" <<'EOF'

[sso-session capsa]
sso_start_url = https://capsa.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
EOF
fi
add_profile() { # name account
  grep -q "^\[profile $1\]" "$CFG" && return 0
  cat >> "$CFG" <<EOF

[profile $1]
sso_session = capsa
sso_account_id = $2
sso_role_name = CapsaAWSDevelopersEDM-UserAccess
region = us-east-1
EOF
}
add_profile dev  110611798842
add_profile qa   491087500610
add_profile prod 698772346265

echo "AWS CLI: $("$BIN" --version)"
echo "Next: $BIN sso login --sso-session capsa --no-browser --use-device-code   (owner approves on phone)"
echo "Then run aws with: env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY $BIN --profile dev ..."
