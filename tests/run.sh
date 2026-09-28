#!/bin/sh
set -eu
container=${1:?Usage: sh tests/run.sh DISPOSABLE_CONTAINER --disposable [NAMESPACE]}
namespace=${3:-USER}
if [ "${2:-}" != "--disposable" ]; then
  echo 'Refusing fixture work without --disposable. Use an isolated instance, not a production namespace.' >&2
  exit 2
fi
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
remote="/tmp/bg-retention-tests-$(date +%s)-$$"
docker cp "$test_dir" "$container:$remote"
docker cp "$test_dir/../demo/cls" "$container:$remote/demo"
output=$(docker exec -i -e BG_RETENTION_TESTS="$remote" "$container" iris session IRIS -U "$namespace" < "$test_dir/run.script")
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^RETENTION TESTS PASSED: '
printf '%s\n' "$output" | grep -q '^RETENTION DEMO TESTS PASSED: '
printf '%s\n' "$output" | grep -q '^RETENTION HOUR TESTS PASSED: '
