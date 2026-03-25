#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="SVNMate"
PROJECT_NAME="${APP_NAME}.xcodeproj"
SCHEME_NAME="${APP_NAME}"
PROJECT_PATH="${REPO_ROOT}/${PROJECT_NAME}"
PROJECT_SPEC_PATH="${REPO_ROOT}/project.yml"
BUILD_DIR="${REPO_ROOT}/build"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
DIST_DIR="${REPO_ROOT}/dist"
DIST_APP_PATH="${DIST_DIR}/${APP_NAME}.app"
DIST_DMG_PATH="${DIST_DIR}/${APP_NAME}-macOS.dmg"
RELEASE_APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/${APP_NAME}.app"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

echo "==> Checking required tools"
require_command xcodebuild
require_command hdiutil

if [[ -f "${PROJECT_SPEC_PATH}" ]]; then
  require_command xcodegen
  echo "==> Generating Xcode project"
  (
    cd "${REPO_ROOT}"
    xcodegen generate
  )
elif [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "Missing Xcode project and project spec: ${PROJECT_PATH}" >&2
  exit 1
fi

echo "==> Building Release app"
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  clean build

if [[ ! -d "${RELEASE_APP_PATH}" ]]; then
  echo "Release app not found at: ${RELEASE_APP_PATH}" >&2
  exit 1
fi

echo "==> Preparing dist directory"
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_APP_PATH}"
ditto "${RELEASE_APP_PATH}" "${DIST_APP_PATH}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/svnmate-dmg.XXXXXX")"
cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

echo "==> Preparing DMG staging content"
ditto "${DIST_APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Creating DMG"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DIST_DMG_PATH}"

echo "==> Packaging complete"
echo "App: ${DIST_APP_PATH}"
echo "DMG: ${DIST_DMG_PATH}"
