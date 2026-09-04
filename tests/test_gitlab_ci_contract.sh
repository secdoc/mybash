#!/bin/sh
set -eu
pipeline="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/.gitlab-ci.yml"
test -f "$pipeline"
for required in CI_CONTAINER_IMAGE docker.io/library/debian:13-slim 'podman run' shellcheck test_secdoc_theme.sh; do
    grep -Fq -- "$required" "$pipeline"
done
for forbidden in --tls-verify=false --userns=keep-id '.home' NEXUS_HOST NEXUS_CI_USERNAME NEXUS_CI_PASSWORD CI_UNTRUSTED_RUNNER_TAG CI_INTERNAL_CA_PATH; do
    if grep -Fq -- "$forbidden" "$pipeline"; then
        exit 1
    fi
done
