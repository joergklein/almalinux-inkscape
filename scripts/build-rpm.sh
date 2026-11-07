#!/usr/bin/env bash

set -Eeuo pipefail

# Inkscape RPM build for AlmaLinux 10 x86_64
# Executed by GitHub Actions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SPEC_FILE="${PROJECT_ROOT}/SPECS/inkscape.spec"
SOURCE_DIR="${PROJECT_ROOT}/SOURCES"
RESULT_DIR="${PROJECT_ROOT}/RPMS"

PACKAGE_NAME="inkscape"
MOCK_CONFIG="alma+epel-10-x86_64"

if [[ -z "${INKSCAPE_VERSION:-}" ]]; then
    echo "Error: INKSCAPE_VERSION is not set."
    exit 1
fi

if [[ ! "${INKSCAPE_VERSION}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "Error: Invalid Inkscape version."
    exit 1
fi

if [[ ! -f "${SPEC_FILE}" ]]; then
    echo "Error: SPEC file not found: ${SPEC_FILE}"
    exit 1
fi

SOURCE_ARCHIVE="${SOURCE_DIR}/${PACKAGE_NAME}-${INKSCAPE_VERSION}.tar.xz"

if [[ ! -f "${SOURCE_ARCHIVE}" ]]; then
    echo "Error: Source archive not found: ${SOURCE_ARCHIVE}"
    exit 1
fi

command -v rpmbuild >/dev/null 2>&1 || {
    echo "Error: rpmbuild is not installed."
    exit 1
}

command -v mock >/dev/null 2>&1 || {
    echo "Error: Mock is not installed."
    exit 1
}

if [[ ! -f "/etc/mock/${MOCK_CONFIG}.cfg" ]]; then
    echo "Error: Mock configuration not found: /etc/mock/${MOCK_CONFIG}.cfg"
    echo "Available AlmaLinux configurations:"
    find /etc/mock -maxdepth 1 -type f -name '*alma*10*x86_64*.cfg' -printf '%f\n' | sort
    exit 1
fi

BUILD_DATE="$(LC_TIME=C date '+%a %b %d %Y')"

BUILD_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "${BUILD_ROOT}"
}

trap cleanup EXIT

mkdir -p \
    "${BUILD_ROOT}/BUILD" \
    "${BUILD_ROOT}/BUILDROOT" \
    "${BUILD_ROOT}/RPMS" \
    "${BUILD_ROOT}/SOURCES" \
    "${BUILD_ROOT}/SPECS" \
    "${BUILD_ROOT}/SRPMS" \
    "${RESULT_DIR}"

find "${RESULT_DIR}" -type f -name '*.rpm' -delete

cp "${SPEC_FILE}" "${BUILD_ROOT}/SPECS/"
cp "${SOURCE_ARCHIVE}" "${BUILD_ROOT}/SOURCES/"

echo "Building ${PACKAGE_NAME}"
echo "Version: ${INKSCAPE_VERSION}"
echo "Build date: ${BUILD_DATE}"
echo "Target: AlmaLinux 10 x86_64 with EPEL 10"
echo "Mock configuration: ${MOCK_CONFIG}"

echo "Creating source RPM..."

rpmbuild \
    --define "_topdir ${BUILD_ROOT}" \
    --define "pkg_version ${INKSCAPE_VERSION}" \
    --define "build_date ${BUILD_DATE}" \
    -bs "${BUILD_ROOT}/SPECS/inkscape.spec"

SRPM_FILE="$(find "${BUILD_ROOT}/SRPMS" -type f -name '*.src.rpm' -print -quit)"

if [[ -z "${SRPM_FILE}" ]]; then
    echo "Error: Source RPM was not generated."
    exit 1
fi

echo "Building binary RPM using Mock..."

if mock \
    --root "${MOCK_CONFIG}" \
    --define "pkg_version ${INKSCAPE_VERSION}" \
    --define "build_date ${BUILD_DATE}" \
    --rebuild "${SRPM_FILE}" \
    --resultdir "${RESULT_DIR}"; then
    MOCK_STATUS=0
else
    MOCK_STATUS=$?
    echo
    echo "Mock build failed with exit code: ${MOCK_STATUS}"
fi

echo
echo "========================================"
echo "Mock build log diagnostics"
echo "========================================"

find "${RESULT_DIR}" -maxdepth 2 -type f -name '*.log' -print

BUILD_LOG="${RESULT_DIR}/build.log"

if [[ -f "${BUILD_LOG}" ]]; then
    echo
    echo "Last build log lines:"
    tail -n 100 "${BUILD_LOG}"

    echo
    echo "Detected errors:"
    grep -n -i -E \
        'error:|fatal error:|undefined reference|No such file|not found|FAILED' \
        "${BUILD_LOG}" | tail -n 60 || true
else
    echo
    echo "No build.log found in ${RESULT_DIR}."

    find "${RESULT_DIR}" -maxdepth 2 -type f -name '*.log' \
        -exec sh -c '
            for file do
                echo
                echo "===== ${file} ====="
                tail -n 100 "$file"
            done
        ' sh {} +
fi

if [[ "${MOCK_STATUS}" -ne 0 ]]; then
    exit "${MOCK_STATUS}"
fi

echo
echo "Verifying generated RPM packages..."

if ! find "${RESULT_DIR}" -type f -name '*.rpm' -print -quit | grep -q .; then
    echo "Error: No RPM packages generated."
    exit 1
fi

echo "Build completed successfully."

find "${RESULT_DIR}" -type f -name '*.rpm' -printf '%f\n' | sort
