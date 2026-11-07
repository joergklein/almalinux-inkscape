#!/usr/bin/env bash

set -Eeuo pipefail

# Collect native Inkscape RPM packages for GitHub Releases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE_DIR="${PROJECT_ROOT}/RPMS"
RELEASE_DIR="${PROJECT_ROOT}/release-assets"

if [[ ! -d "${SOURCE_DIR}" ]]; then
    echo "Error: RPM directory not found: ${SOURCE_DIR}"
    exit 1
fi

if ! command -v rpm >/dev/null 2>&1; then
    echo "Error: RPM tools are not installed."
    exit 1
fi

mkdir -p "${RELEASE_DIR}"

# Remove previously collected RPM files
find "${RELEASE_DIR}" -maxdepth 1 -type f -name '*.rpm' -delete

echo "Collecting RPM packages..."

RPM_COUNT=0
declare -A SEEN_PACKAGES=()

while IFS= read -r -d '' RPM_FILE; do
    RPM_NAME="$(basename "${RPM_FILE}")"

    if [[ -n "${SEEN_PACKAGES[${RPM_NAME}]:-}" ]]; then
        echo "Error: Duplicate RPM filename: ${RPM_NAME}"
        exit 1
    fi

    SEEN_PACKAGES["${RPM_NAME}"]=1

    echo "Checking: ${RPM_NAME}"

    rpm -K "${RPM_FILE}"

    cp "${RPM_FILE}" "${RELEASE_DIR}/"

    RPM_COUNT=$((RPM_COUNT + 1))

done < <(
    find "${SOURCE_DIR}" -type f -name '*.rpm' -print0
)

if [[ "${RPM_COUNT}" -eq 0 ]]; then
    echo "Error: No RPM packages found."
    exit 1
fi

echo
echo "Successfully collected ${RPM_COUNT} RPM package(s):"

find "${RELEASE_DIR}" -maxdepth 1 -type f -name '*.rpm' -printf '%f\n' | sort

echo
echo "Release assets directory:"
echo "${RELEASE_DIR}"
