#!/usr/bin/env bash

# CLI FORMAT: sudo ./disk-events.sh set --label=<disk label> --path=<path> --timeout=<timeout> --command=<command> --fswatch=<fswatch options>

set -o errexit
set -o pipefail
set -o nounset
# [[ "${debug}" == 'true' ]] && set -o xtrace

readonly dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "lib/disk-events.sh"