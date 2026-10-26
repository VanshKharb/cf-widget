#!/bin/bash
# Re-signs and reinstalls the app on your iPhone.
#
# Apps signed with a free Apple ID stop opening after 7 days. Plug the phone in,
# unlock it, and run this. It rebuilds, reinstalls, and relaunches.
#
#   ./Tools/renew.sh
#   DEVICE_UDID=00008110-000155080113801E ./Tools/renew.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f Config/Identity.xcconfig ]]; then
  echo "error: Config/Identity.xcconfig is missing. Run ./Tools/setup.sh first." >&2
  exit 1
fi

PREFIX="$(awk -F'=' '/^BUNDLE_PREFIX/ {gsub(/[[:space:]]/, "", $2); print $2}' Config/Identity.xcconfig)"
BUNDLE_ID="${PREFIX}.homejudge"

UDID="${DEVICE_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun devicectl list devices 2>/dev/null \
    | grep 'physical' \
    | grep -v 'simulated' \
    | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{8,}' \
    | head -1 || true)"
fi

if [[ -z "$UDID" ]]; then
  echo "No iPhone found." >&2
  echo "Plug it in with a cable, unlock it, and tap Trust on the phone." >&2
  exit 1
fi

echo "Device:   $UDID"
echo "Bundle:   $BUNDLE_ID"
echo
echo "Keep the iPhone unlocked and awake during this."
echo

xcodebuild -quiet -scheme Homejudge -destination "id=$UDID" -allowProvisioningUpdates build

APP="$(xcodebuild -scheme Homejudge -destination "id=$UDID" -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR =/ {d=$3} / FULL_PRODUCT_NAME =/ {n=$3} END {print d "/" n}')"

if [[ ! -d "$APP" ]]; then
  echo "error: could not locate the built app at '${APP}'." >&2
  exit 1
fi

xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Renewed — this build is good for another 7 days."
