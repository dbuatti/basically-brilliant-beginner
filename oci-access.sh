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

# ── 2. tenancy, user, region from environment variables ───────────────────
# The Cloud Shell exposes these directly. OCI_TENANCY and OCI_CS_USER_OCID
# are set in every Cloud Shell session.
say "Reading your tenancy, user and region from the Cloud Shell environment…"
TENANCY="${OCI_TENANCY:-}"
USER_OCID="${OCI_CS_USER_OCID:-}"
REGION=""

# Region: extract from the terminal OCID or the hostname.
if [ -n "${OCI_CS_TERMINAL_OCID:-}" ]; then
  REGION=$(echo "$OCI_CS_TERMINAL_OCID" | grep -oE 'ap-[a-z]+-[0-9]+' | head -1)
fi
if [ -z "$REGION" ]; then
  REGION=$(hostname 2>/dev/null | grep -oE 'ap-[a-z]+-[0-9]+' | head -1)
fi
if [ -z "$REGION" ]; then
  # Last resort: parse from the prompt or the OCI config if it exists.
  if [ -f "$HOME/.oci/config" ]; then
    REGION=$(grep -E '^region=' "$HOME/.oci/config" | head -1 | cut -d= -f2- | tr -d '[:space:]')
  fi
fi

[ -n "$TENANCY" ] || TENANCY="PASTE_YOUR_TENANCY_OCID_HERE"
[ -n "$USER_OCID" ] || USER_OCID="PASTE_YOUR_USER_OCID_HERE"
[ -n "$REGION" ] || REGION="PASTE_YOUR_REGION_HERE"

say "  tenancy: $TENANCY"
say "  user:    $USER_OCID"
say "  region:  $REGION"

# ── 3. add the public key to your user ─────────────────────────────────────
say "Adding the public key to your Oracle user…"
ADDED=0

# Try the newer CLI spelling first.
if [ "$USER_OCID" != "PASTE_YOUR_USER_OCID_HERE" ]; then
  if oci iam user api-key upload \
        --user-id "$USER_OCID" \
        --key-file opencode_api_key_public.pem >/dev/null 2>&1; then
    ADDED=1
  fi
fi

# Try the older CLI spelling.
if [ "$ADDED" -eq 0 ] && [ "$USER_OCID" != "PASTE_YOUR_USER_OCID_HERE" ]; then
  if oci iam api-key add \
        --user-id "$USER_OCID" \
        --key-file opencode_api_key_public.pem \
        --key-name "opencode-ops-$(date +%Y%m%d)" >/dev/null 2>&1; then
    ADDED=1
  fi
fi

if [ "$ADDED" -eq 0 ]; then
  warn "The CLI could not add the API key by itself."
  warn "(The Cloud Shell authenticates as the instance, not as you, so it"
  warn " may not have permission to add keys to your user.)"
  warn ""
  warn "Do it by hand — it takes about a minute:"
  warn ""
  warn "   1. Identity & Security -> Domains -> Users -> your user"
  warn "   2. -> API Keys -> Add API Key"
  warn "   3. Paste the contents of this file:"
  warn "        $WORKDIR/opencode_api_key_public.pem"
  warn ""
  warn "   Or upload the file directly from the file browser."
  warn ""
fi

# ── 4. fingerprint ─────────────────────────────────────────────────────────
# The fingerprint is the md5 of the public key in DER form, with colons.
# The fingerprint is the md5 of the public key in DER form, with colons.
# Try openssl md5 -c first (outputs colons natively).
FINGERPRINT=$(openssl rsa -pubin -in opencode_api_key_public.pem -outform der 2>/dev/null \
              | openssl md5 -c 2>/dev/null | sed 's/^.*= //')
if [ -z "$FINGERPRINT" ] || [ "$FINGERPRINT" = "None" ]; then
  # Some openssl versions need dgst.
  FINGERPRINT=$(openssl rsa -pubin -in opencode_api_key_public.pem -outform der 2>/dev/null \
                | openssl dgst -md5 -c 2>/dev/null | sed 's/^.*= //')
fi
if [ -z "$FINGERPRINT" ] || [ "$FINGERPRINT" = "None" ]; then
  # Last resort: compute without colons, then insert them.
  RAW=$(openssl rsa -pubin -in opencode_api_key_public.pem -outform der 2>/dev/null \
        | openssl md5 2>/dev/null | sed 's/^.*= //; s/ //g')
  if [ -n "$RAW" ]; then
    FINGERPRINT=$(echo "$RAW" | sed 's/../&:/g; s/:$//')
  fi
fi
[ -n "$FINGERPRINT" ] || FINGERPRINT="PASTE_YOUR_FINGERPRINT_HERE"

# ── 5. the block to paste back ────────────────────────────────────────────
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
say "The public key (in case you need to paste it by hand):"
cat opencode_api_key_public.pem
say ""
say "=========================================================================="
say ""
