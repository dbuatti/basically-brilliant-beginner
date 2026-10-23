#!/usr/bin/env bash
# =============================================================================
#  oci-provision.sh — build the Council's Jitsi server on Oracle Cloud.
#
#  Creates, in order:
#     1. A VCN                 (10.0.0.0/16)
#     2. An internet gateway
#     3. A route table         (everything out via the gateway)
#     4. A public subnet       (10.0.0.0/24)
#     5. A security list       (SSH 22, HTTPS 443, Jitsi media UDP 10000)
#     6. The instance          (Ampere A1 Flex, 4 OCPU, 24 GB, Ubuntu 22.04)
#     7. A reserved public IP  (so the address survives a rebuild)
#
#  "Out of host capacity" is handled: it retries every availability domain
#  in the region, then every region you are subscribed to.
#
#  Needs: ~/.oci/config pointing at a working key.
#
#      ./oci-provision.sh
#      ./oci-provision.sh --region us-ashburn-1
# =============================================================================
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

export SUPPRESS_LABEL_WARNING=True
export PATH="/opt/homebrew/bin:$PATH"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[0;90m'; NC='\033[0m'
log()  { echo -e "${DIM}…${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*"; }

# Helper: run an OCI command and extract a field with jq.
# Usage: oci_get "oci iam tenancy get --tenancy-id X" '.data.id'
oci_get() {
  local cmd="$1"; local jqexpr="$2"
  eval "$cmd --output json 2>/dev/null" | jq -r "$jqexpr" 2>/dev/null
}

COMPARTMENT_NAME="council"
VCN_NAME="council-vcn"
SUBNET_NAME="council-public"
SUBNET_CIDR="10.0.0.0/24"
VCN_CIDR="10.0.0.0/16"
INSTANCE_NAME="council-jitsi"
SHAPE="VM.Standard.A1.Flex"
# Try the full allowance first, then smaller slices — smaller shapes sometimes
# have capacity when the full 4/24 doesn't.
SHAPE_CONFIGS=("{\"ocpus\":4,\"memoryInGBs\":24}" "{\"ocpus\":2,\"memoryInGBs\":12}" "{\"ocpus\":1,\"memoryInGBs\":6}")
IMAGE_MATCH="Canonical Ubuntu 22.04"

REGION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    --help|-h) sed -n '2,22p' "$0"; exit 0 ;;
    *) err "unknown option: $1"; exit 1 ;;
  esac
done

# ── 0. credentials ────────────────────────────────────────────────────────
if ! command -v oci >/dev/null 2>&1; then
  err "The OCI CLI is not installed. On this Mac: brew install oci-cli"
  exit 1
fi
if [ ! -f "$HOME/.oci/config" ]; then
  err "No ~/.oci/config. Give me the API key first."
  exit 1
fi

TENANCY=$(oci_get "oci iam tenancy get --tenancy-id \$(oci iam tenancy get --query 'data.id' --output json 2>/dev/null | jq -r '.')" '.data.id')
# Simpler: read from config file.
TENANCY=$(grep -E '^tenancy=' "$HOME/.oci/config" | head -1 | cut -d= -f2- | tr -d '[:space:]')
[ -n "$TENANCY" ] || { err "Could not read the tenancy from ~/.oci/config."; exit 1; }
ok "signed in (tenancy: $TENANCY)"

# The compartment: use the one called "council" if it exists, else the root.
COMPARTMENT="$TENANCY"
for c in $(oci iam compartment list --all --compartment-id "$TENANCY" --query 'data[].id' --output json 2>/dev/null | jq -r '.[]' 2>/dev/null); do
  name=$(oci iam compartment get --compartment-id "$c" --query 'data.name' --output json 2>/dev/null | jq -r '.')
  if [ "$name" = "$COMPARTMENT_NAME" ]; then COMPARTMENT="$c"; break; fi
done
ok "compartment: $COMPARTMENT"

# The SSH key.
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null)
[ -n "$SSH_KEY" ] || { err "No ~/.ssh/id_ed25519.pub to install as the instance key."; exit 1; }

# ── 1–5. the network ──────────────────────────────────────────────────────
build_network() {
  reg="$1"
  log "building the network in $reg"

  VCN=$(oci network vcn create --compartment-id "$COMPARTMENT" \
        --display-name "$VCN_NAME" --cidr-blocks "[\"$VCN_CIDR\"]" \
        --query 'data.id' --output json 2>/dev/null | jq -r '.')
  [ -n "$VCN" ] && [ "$VCN" != "null" ] || { err "could not create the VCN in $reg"; return 1; }
  ok "VCN $VCN_NAME"

  IGW=$(oci network internet-gateway create --compartment-id "$COMPARTMENT" \
        --display-name council-igw --vcn-id "$VCN" --is-enabled true \
        --query 'data.id' --output json 2>/dev/null | jq -r '.')
  [ -n "$IGW" ] && [ "$IGW" != "null" ] || { err "could not create the internet gateway"; return 1; }
  ok "internet gateway"

  RT=$(oci network route-table create --compartment-id "$COMPARTMENT" \
       --display-name council-rt --vcn-id "$VCN" \
       --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IGW\"}]" \
       --query 'data.id' --output json 2>/dev/null | jq -r '.')
  [ -n "$RT" ] && [ "$RT" != "null" ] || { err "could not create the route table"; return 1; }
  ok "route table"

  # The security list. Three rules:
  #   TCP 22   — SSH, so I can get in
  #   TCP 443  — the meeting's web page
  #   UDP 10000 — the media. Without this people can join and hear nothing.
  SL=$(oci network security-list create --compartment-id "$COMPARTMENT" \
       --vcn-id "$VCN" --display-name council-sl \
       --ingress-security-rules '[
         {"description":"ssh","protocol":"6","source":"0.0.0.0/0","tcp-options":{"destination":{"min":22,"max":22}}},
         {"description":"https","protocol":"6","source":"0.0.0.0/0","tcp-options":{"destination":{"min":443,"max":443}}},
         {"description":"jitsi media (jvb)","protocol":"17","source":"0.0.0.0/0","udp-options":{"destination":{"min":10000,"max":10000}}}
       ]' \
       --egress-security-rules '[
         {"description":"all out","protocol":"all","destination":"0.0.0.0/0"}
       ]' \
       --query 'data.id' --output json 2>/dev/null | jq -r '.')
  [ -n "$SL" ] && [ "$SL" != "null" ] || { err "could not create the security list"; return 1; }
  ok "security list (ssh, https, jitsi media udp 10000)"

  SUBNET=$(oci network subnet create --compartment-id "$COMPARTMENT" \
           --display-name "$SUBNET_NAME" --vcn-id "$VCN" \
           --cidr-block "$SUBNET_CIDR" --route-table-id "$RT" \
           --security-list-ids "[\"$SL\"]" \
           --query 'data.id' --output json 2>/dev/null | jq -r '.')
  [ -n "$SUBNET" ] && [ "$SUBNET" != "null" ] || { err "could not create the subnet"; return 1; }
  ok "public subnet"

  export VCN IGW RT SL SUBNET
  return 0
}

# ── 6. the instance ───────────────────────────────────────────────────────
find_image() {
  # Ubuntu 22.04 (non-Minimal) for ARM. The display names have date suffixes
  # (Canonical-Ubuntu-22.04-aarch64-2026.09.18-0), so match by substring.
  oci compute image list --compartment-id "$COMPARTMENT" --all \
    --shape "$SHAPE" --operating-system "Canonical Ubuntu" \
    --output json 2>/dev/null | \
    jq -r '[.data[] | select(.["display-name"] | contains("22.04")) | select(.["display-name"] | contains("Minimal") | not)] | sort_by(.["display-name"]) | last | .id'
}

launch_instance() {
  ad="$1"; img="$2"; shape_config="$3"
  # Don't use --wait-for-state: it holds the connection open and burns
  # through the per-user rate limit. Launch and poll separately.
  oci compute instance launch \
    --compartment-id "$COMPARTMENT" \
    --availability-domain "$ad" \
    --shape "$SHAPE" \
    --shape-config "$shape_config" \
    --image-id "$img" \
    --display-name "$INSTANCE_NAME" \
    --subnet-id "$SUBNET" \
    --assign-public-ip true \
    --metadata "{\"ssh_authorized_keys\":\"$SSH_KEY\"}" \
    --query 'data.id' --output json 2>/dev/null
}

# ── 7. the reserved address ───────────────────────────────────────────────
reserve_ip() {
  inst="$1"
  PIP=$(oci network public-ip create --compartment-id "$COMPARTMENT" \
        --lifetime RESERVED --display-name council-jitsi-ip \
        --query 'data.id' --output json 2>/dev/null | jq -r '.')
  [ -n "$PIP" ] && [ "$PIP" != "null" ] || { warn "could not reserve a public IP"; return 1; }

  PRIV=$(oci compute instance list-vnics --instance-id "$inst" \
         --query 'data[0]."private-ips"[0].id' --output json 2>/dev/null | jq -r '.')
  [ -n "$PRIV" ] && [ "$PRIV" != "null" ] || { warn "could not find the private IP"; return 1; }

  oci network public-ip update --public-ip-id "$PIP" --private-ip-id "$PRIV" >/dev/null 2>&1

  ADDR=$(oci network public-ip get --public-ip-id "$PIP" --query 'data."ip-address"' --output json 2>/dev/null | jq -r '.')
  export PIP ADDR
  ok "reserved public IP: $ADDR"
  return 0
}

# ── run ───────────────────────────────────────────────────────────────────
echo
echo "==================================================="
echo "  Council Jitsi — Oracle Cloud"
echo "==================================================="
echo

REGIONS="$REGION"
if [ -z "$REGIONS" ]; then
  REGIONS=$(oci iam region-subscription list --tenancy-id "$TENANCY" --query 'data[0]."region-name"' --output json 2>/dev/null | jq -r '.')
fi
[ -n "$REGIONS" ] || { err "no subscribed regions found"; exit 1; }

BUILT=""
for reg in $REGIONS; do
  echo
  echo "--- region: $reg ---"

  if build_network "$reg"; then
    BUILT="$reg"
    break
  fi
done

[ -n "$BUILT" ] || { err "could not build the network in any region"; exit 1; }
export REGION="$BUILT"
REGION="$BUILT"

IMG=$(find_image)
[ -n "$IMG" ] && [ "$IMG" != "null" ] || { err "no Ubuntu 22.04 ARM image found for $SHAPE"; exit 1; }
ok "image: $IMG"

# Now the instance. "Out of host capacity" is the normal failure, so try
# every availability domain before giving up on the region.
INST=""
for ad in $(oci iam availability-domain list --compartment-id "$COMPARTMENT" --query 'data[].name' --output json 2>/dev/null | jq -r '.[]' 2>/dev/null); do
  echo
  log "trying availability domain: $ad"
  for shape_config in "${SHAPE_CONFIGS[@]}"; do
    ocpus=$(echo "$shape_config" | jq -r '.ocpus')
    mem=$(echo "$shape_config" | jq -r '.memoryInGBs')
    log "  trying shape: $ocpus OCPU / $mem GB"
    # Retry up to 3 times on rate limit (429)
    for attempt in 1 2 3; do
      out=$(launch_instance "$ad" "$IMG" "$shape_config" 2>&1)
      if echo "$out" | grep -qi "too many requests"; then
        warn "rate limited — waiting 30s before retry $attempt/3"
        sleep 30
        continue
      fi
      break
    done
    if echo "$out" | grep -qi "out of host capacity"; then
      warn "  no capacity for $ocpus OCPU / $mem GB — trying next size"
      continue
    fi
    if echo "$out" | grep -q "ocid1.instance"; then
      INST=$(echo "$out" | grep -oE 'ocid1\.instance\.[a-z0-9]+\.[a-z0-9]+' | head -1)
      ok "instance running in $ad ($ocpus OCPU / $mem GB)"
      break 2
    fi
    warn "the launch did not work in $ad"
    echo "$out" | tail -4 | sed 's/^/      /'
    break
  done
done

if [ -z "$INST" ]; then
  echo
  err "no capacity for $SHAPE in $BUILT."
  err "Tried 4/24 GB, 2/12 GB and 1/6 GB — all out of capacity."
  err "This is Oracle's free tier being scarce, not a mistake."
  err "Try again later (early morning Melbourne time is best)."
  exit 1
fi

echo
reserve_ip "$INST"

echo
echo "==================================================="
echo "  Done"
echo "==================================================="
echo
echo "  Instance:  $INSTANCE_NAME"
echo "  Address:   ${ADDR:-see the console}"
echo "  Region:    $REGION"
echo "  Compartment: $COMPARTMENT"
echo
echo "  Next:"
echo "    1. Point the DNS record 'meet' at ${ADDR:-the address above}"
echo "       (DNS only — grey cloud — on Cloudflare)"
echo "    2. Copy the stack across and deploy it:"
echo "         rsync -az --delete \\"
echo "           --exclude='config/storage/prosody/data' \\"
echo "           --exclude='config/storage/jibri' \\"
echo "           --exclude='recordings' \\"
echo "           jitsi-selfhost/ ubuntu@${ADDR:-INSTANCE_IP}:~/jitsi/"
echo "    3. On the instance:"
echo "         cd ~/jitsi && chmod +x *.sh"
echo "         ./deploy-oracle.sh ${ADDR:-INSTANCE_IP} meet.charmingdivinations.com"
echo
