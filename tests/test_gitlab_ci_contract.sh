#!/bin/sh
set -eu
pipeline="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/.gitlab-ci.yml"
test -f "$pipeline"
for required in phase4-untrusted nexus.secdoc.home NEXUS_CI_USERNAME NEXUS_CI_PASSWORD 'podman run' shellcheck test_secdoc_theme.sh; do
    grep -Fq -- "$required" "$pipeline"
done
for forbidden in --tls-verify=false deb.debian.org github.com/koalaman; do
    if grep -Fq -- "$forbidden" "$pipeline"; then
        exit 1
    fi
done
