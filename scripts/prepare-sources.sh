#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE_DIR="${PROJECT_ROOT}/SOURCES"
PATCH_DIR="${SOURCE_DIR}/patches"

REPOSITORY="https://gitlab.com/inkscape/inkscape.git"
TAGS_API="https://gitlab.com/api/v4/projects/inkscape%2Finkscape/repository/tags?per_page=100&order_by=version&sort=desc"

if [[ $# -ne 0 ]]; then
    echo "Error: No version argument is required."
    exit 1
fi

mkdir -p "${SOURCE_DIR}" "${PATCH_DIR}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Retrieving stable release tags..."

TAGS_JSON="$(curl \
    --fail \
    --location \
    --retry 3 \
    --silent \
    --show-error \
    "${TAGS_API}")"

LATEST_TAG="$(
    printf '%s' "${TAGS_JSON}" |
    grep -oE '"name"[[:space:]]*:[[:space:]]*"INKSCAPE_[0-9]+_[0-9]+_[0-9]+"' |
    sed -E 's/.*"INKSCAPE_([0-9]+)_([0-9]+)_([0-9]+)"/INKSCAPE_\1_\2_\3/' |
    sort -V |
    tail -n 1
)"

if [[ -z "${LATEST_TAG}" ]]; then
    echo "Error: No stable release tag found."
    exit 1
fi

PACKAGE_VERSION="${LATEST_TAG#INKSCAPE_}"
PACKAGE_VERSION="${PACKAGE_VERSION//_/.}"

echo "Selected version: ${PACKAGE_VERSION}"
echo "Selected tag: ${LATEST_TAG}"
echo "Downloading source and submodules..."

CHECKOUT_DIR="${WORK_DIR}/inkscape-${PACKAGE_VERSION}"

git clone \
    --depth 1 \
    --single-branch \
    --branch "${LATEST_TAG}" \
    --recurse-submodules \
    --shallow-submodules \
    "${REPOSITORY}" \
    "${CHECKOUT_DIR}"

echo "Applying Inkscape patches..."

shopt -s nullglob
PATCH_FILES=("${PATCH_DIR}"/*.patch)

if [[ ${#PATCH_FILES[@]} -eq 0 ]]; then
    echo "No patch files found. Continuing without patches."
else
    for PATCH_FILE in "${PATCH_FILES[@]}"; do
        echo "Checking patch: $(basename "${PATCH_FILE}")"

        git -C "${CHECKOUT_DIR}" apply --check "${PATCH_FILE}"

        echo "Applying patch: $(basename "${PATCH_FILE}")"
        git -C "${CHECKOUT_DIR}" apply "${PATCH_FILE}"

        echo "Patch applied successfully."
    done
fi

echo "All patches processed successfully."

echo "Determining Inkscape source revision..."

INKSCAPE_REVISION="$(git -C "${CHECKOUT_DIR}" rev-parse --short=10 HEAD)"
INKSCAPE_REVISION_DATE="$(git -C "${CHECKOUT_DIR}" log -1 --format=%cs)"

if [[ -z "${INKSCAPE_REVISION}" || -z "${INKSCAPE_REVISION_DATE}" ]]; then
    echo "Error: Could not determine Inkscape revision information."
    exit 1
fi

echo "Revision: ${INKSCAPE_REVISION}"
echo "Revision date: ${INKSCAPE_REVISION_DATE}"

echo "Updating Inkscape version configuration..."

VERSION_FILE="${CHECKOUT_DIR}/CMakeScripts/inkscape-version.cmake"

if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "Error: Inkscape version configuration not found:"
    echo "${VERSION_FILE}"
    exit 1
fi

if ! grep -Fxq 'set(INKSCAPE_REVISION "unknown")' "${VERSION_FILE}"; then
    echo "Error: Unexpected INKSCAPE_REVISION definition."
    echo "The upstream version configuration may have changed."
    exit 1
fi

sed -i \
    "s|^set(INKSCAPE_REVISION \"unknown\")$|set(INKSCAPE_REVISION \"${INKSCAPE_REVISION}, ${INKSCAPE_REVISION_DATE}\")|" \
    "${VERSION_FILE}"

EXPECTED_REVISION="set(INKSCAPE_REVISION \"${INKSCAPE_REVISION}, ${INKSCAPE_REVISION_DATE}\")"

if ! grep -Fxq "${EXPECTED_REVISION}" "${VERSION_FILE}"; then
    echo "Error: Failed to update Inkscape revision configuration."
    exit 1
fi

echo "Verified revision configuration:"
grep -F "${EXPECTED_REVISION}" "${VERSION_FILE}"

echo "Creating source archive..."

SOURCE_ARCHIVE="inkscape-${PACKAGE_VERSION}.tar.xz"
SOURCE_PATH="${SOURCE_DIR}/${SOURCE_ARCHIVE}"
TEMP_PATH="${SOURCE_PATH}.tmp"

tar \
    --create \
    --xz \
    --file="${TEMP_PATH}" \
    --directory="${WORK_DIR}" \
    --exclude-vcs \
    "inkscape-${PACKAGE_VERSION}"

echo "Verifying source archive..."

tar -tJf "${TEMP_PATH}" > /dev/null

if ! tar -xOJf "${TEMP_PATH}" \
    "inkscape-${PACKAGE_VERSION}/CMakeScripts/inkscape-version.cmake" |
    grep -Fxq "${EXPECTED_REVISION}"; then
    echo "Error: Revision information missing from source archive."
    rm -f "${TEMP_PATH}"
    exit 1
fi

mv "${TEMP_PATH}" "${SOURCE_PATH}"

if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
        echo "INKSCAPE_VERSION=${PACKAGE_VERSION}"
        echo "INKSCAPE_REVISION=${INKSCAPE_REVISION}"
        echo "INKSCAPE_REVISION_DATE=${INKSCAPE_REVISION_DATE}"
    } >> "${GITHUB_ENV}"
fi

echo
echo "Source preparation completed."
echo "Version: ${PACKAGE_VERSION}"
echo "Revision: ${INKSCAPE_REVISION}"
echo "Revision date: ${INKSCAPE_REVISION_DATE}"
echo "Archive: ${SOURCE_PATH}"
