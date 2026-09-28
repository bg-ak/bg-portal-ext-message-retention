#!/bin/sh
# Install into an existing Portal container. No role changes or demo data.
set -eu
container=${1:?Usage: sh scripts/install.sh PORTAL_CONTAINER [NAMESPACE]}
namespace=${2:-USER}
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
remote="/tmp/bg-retention-install-$(date +%s)-$$"
docker exec "$container" mkdir -p "$remote"
docker cp "$root/module.xml" "$container:$remote/module.xml"
docker cp "$root/src" "$container:$remote/src"
output=$(docker exec -i -e BG_RETENTION_PACKAGE="$remote" "$container" iris session IRIS -U "$namespace" < "$root/scripts/install.script")
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^RETENTION INSTALL PASSED$'
printf '\nOpen your Portal: /csp/portal/BG.Retention.Portal.Page.cls\n'
