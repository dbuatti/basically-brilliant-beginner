#!/bin/bash
# Deploy the site to Vercel.
# Vercel's free tier allows 100 deployments per account per day. If you hit
# "Resource is limited - try again in 24 hours", wait for the UTC day to
# roll over (00:00 UTC = 10:00am AEDT / 8:00pm AEST) and run this again.
#
#   ./deploy.sh          → production
#   ./deploy.sh preview  → preview URL

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ "${1:-prod}" = "preview" ]; then
  exec vercel deploy --yes
else
  exec vercel --prod --yes
fi
