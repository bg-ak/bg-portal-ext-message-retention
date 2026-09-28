#!/bin/sh
set -eu
container=${1:?Usage: sh demo/seed.sh DISPOSABLE_PORTAL_CONTAINER --disposable [NAMESPACE]}
namespace=${3:-USER}
if [ "${2:-}" != "--disposable" ]; then
  echo 'Use --disposable only for an isolated demo instance with an empty header store.' >&2
  exit 2
fi
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
remote="/tmp/bg-retention-demo-$(date +%s)-$$"
docker cp "$root/cls" "$container:$remote"
output=$(docker exec -i -e BG_RETENTION_DEMO="$remote" "$container" iris session IRIS -U "$namespace" < "$root/seed.script")
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^RETENTION DEMO SEEDED: '
