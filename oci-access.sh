#!/usr/bin/env bash
# =============================================================================
#  oci-access.sh — give the Council's assistant access to your Oracle Cloud
#  tenancy, in one paste.
#
#  Run this in the Oracle Cloud Shell (already signed in as you). It makes a
#  key pair, adds the public half to your Oracle user, works out your tenancy,
#  user and region, and prints a ready-made ~/.oci/config block.
#
#  The PRIVATE key never goes through the chat. It is written to a file in
#  Cloud Shell, and you download that file to your Mac.
#
#  Afterwards: delete the API key (Identity & Security -> Domains -> Users ->
#  your user -> API Keys). The work will be done by then.
# =============================================================================
set -uo pipefail

say()  { printf "\033[1;33m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
fail() { printf "\033[0;31m[ERR ]\033[0m %s\n" "$*" >&2; exit 1; }

say ""
say "Preparing access for the Council's assistant…"
say ""

# A plain folder, not a dot-directory: the Cloud Shell file browser hides
# dot-files, and the private key has to be easy to find to download.
WORKDIR="$HOME/oracle-access"
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"
cd "$WORKDIR" || fail "cannot write to $WORKDIR"

# ── 1. the key pair ───────────────────────────────────────────────────────
rm -f opencode_api_key.pem opencode_api_key_public.pem
openssl genrsa -out opencode_api_key.pem 2048 2>/dev/null || fail "openssl could not make a key"
chmod 600 opencode_api_key.pem
openssl rsa -in opencode_api_key.pem -pubout -out opencode_api_key_public.pem 2>/dev/null || fail "could not extract the public key"

# ── 2. find your user ──────────────────────────────────────────────────────
say "Finding your Oracle user…"
SHELL_USER="$(id -un)"
USER_OCID=$(oci iam user list --all \
  --query "data[?\"name\"=='$SHELL_USER'].\"ocid\"" --output text 2>/dev/null | head -1 | tr -d '[:space:]')

if [ -z "$USER_OCID" ] || [ "$USER_OCID" = "None" ]; then
  # Fall back to the first user (the list is usually short).
  USER_OCID=$(oci iam user list --all --output text 2>/dev/null \
    | awk '$2 ~ /^ocid1\.user/ {print $2; exit}')
fi
[ -n "$USER_OCID" ] || USER_OCID="PASTE_YOUR_USER_OCID_HERE"

say "  your user: $USER_OCID"

# ── 3. add the public key to your user ─────────────────────────────────────
say "Adding the public key to your Oracle user…"
ADDED=0

# Newer CLI (3.9x): api-key commands live under "iam user api-key".
if oci iam user api-key upload \
      --user-id "$USER_OCID" \
      --key-file opencode_api_key_public.pem >/dev/null 2>&1; then
  ADDED=1
fi

# Older CLI (and the one Cloud Shell usually bundles).
if [ "$ADDED" -eq 0 ]; then
  if oci iam api-key add \
        --key-name "opencode-ops-$(date +%Y%m%d)" \
        --key-file opencode_api_key_public.pem \
        --display-name "Council's assistant - temporary" >/dev/null 2>&1; then
    ADDED=1
  fi
fi

if [ "$ADDED" -eq 0 ]; then
  warn "The CLI could not add the API key by itself."
  warn "Do it by hand — it takes about a minute:"
  warn ""
  warn "   Identity & Security -> Domains -> Users -> your user"
  warn "   -> API Keys -> Add API Key -> Paste the public key"
  warn ""
  warn "The public key is in: $WORKDIR/opencode_api_key_public.pem"
  warn "Paste its contents into the console, or upload the file."
  warn ""
fi

# ── 4. fingerprint ─────────────────────────────────────────────────────────
# The fingerprint is the md5 of the public key in DER form, with colons.
FINGERPRINT=$(openssl rsa -pubin -in opencode_api_key_public.pem -outform der 2>/dev/null \
              | openssl md5 2>/dev/null | sed 's/^.*= //; s/ //g')
if [ -z "$FINGERPRINT" ] || [ "$FINGERPRINT" = "None" ]; then
  # Some openssl versions format differently.
  FINGERPRINT=$(openssl rsa -pubin -in opencode_api_key_public.pem -outform der 2>/dev/null \
                | openssl dgst -md5 2>/dev/null | sed 's/^.*= //; s/ //g')
fi
[ -n "$FINGERPRINT" ] || FINGERPRINT="PASTE_YOUR_FINGERPRINT_HERE"

# ── 5. tenancy and region ──────────────────────────────────────────────────
say "Working out your tenancy and region…"
TENANCY=$(oci iam tenancy get --query 'data.id' --output text 2>/dev/null)
[ -n "$TENANCY" ] && [ "$TENANCY" != "None" ] || TENANCY="PASTE_YOUR_TENANCY_OCID_HERE"

REGION=$(oci iam region-subscription list \
  --query 'data[0]."region-name"' --output text 2>/dev/null | head -1 | tr -d '[:space:]')
if [ -z "$REGION" ] || [ "$REGION" = "None" ]; then
  REGION=$(curl -s --max-time 8 \
    -H "Authorization: Bearer $OCI_PRIVKEY" \
    http://169.254.169.254/opc/v2/instance/ 2>/dev/null \
    | grep -o '"regionId":"[^"]*' | head -1 | cut -d'"' -f4)
fi
[ -n "$REGION" ] || REGION="PASTE_YOUR_REGION_HERE"

# ── 6. the block to paste back ────────────────────────────────────────────
say ""
say "=========================================================================="
say " PASTE THIS BACK TO THE ASSISTANT"
say "=========================================================================="
say ""
cat <<EOF
[DEFAULT]
user=$USER_OCID
fingerprint=$FINGERPRINT
private_key_file=~/Downloads/oracle_opencode_api_key.pem
tenancy=$TENANCY
region=$REGION
EOF
say ""
say "=========================================================================="
say ""
say "And download the private key:"
say ""
say "   1. In the Cloud Shell file browser on the LEFT of the panel, open the"
say "      'oracle-access' folder"
say "   2. Right-click  opencode_api_key.pem  ->  Download"
say "   3. Move it to your Downloads folder on the Mac, and rename it to"
say "        oracle_opencode_api_key.pem"
say ""
say "   Then tell the assistant it is at:"
say "        ~/Downloads/oracle_opencode_api_key.pem"
say ""
say "The private key never needs to go through the chat."
say ""
say "   If the file browser is not showing, toggle it with the small"
say "   folder icon at the top-left of the Cloud Shell panel."
say ""
say "=========================================================================="
say ""
say "Every user in the tenancy, in case you need to pick a different OCID:"
oci iam user list --all --output text 2>/dev/null | head -20 | sed 's/^/   /'
say ""
say "Subscribed regions:"
oci iam region-subscription list --output text 2>/dev/null | head -10 | sed 's/^/   /'
say ""
