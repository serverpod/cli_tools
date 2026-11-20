#!/usr/bin/env bash
# Publish config and cli_tools to Quiver as pre-release versions that share a
# channel suffix: <base>-<channel>.<n>, where <n> is one higher than any build
# of that channel already on the registry.
#
# Usage:
#   melos run publish:quiver
#   tool/publish_to_quiver.sh
#
# The channel is preview-<branch>, where <branch> is the current git branch
# (for example preview-main or preview-new-better-command).
# Authentication uses the credential from `dart pub token add` for the
# registry. PUB_TOKEN (or QUIVER_TOKEN) is used when no credential is
# configured. A stored credential that names PUB_TOKEN still needs that
# variable exported. Requires curl, jq, git, and dart.

set -euo pipefail

REGISTRY="https://quiver.serverpod.space/registry/christer"
PACKAGES=(config cli_tools)

usage() {
  cat <<EOF
Usage: melos run publish:quiver

Publish config and cli_tools to Quiver as <base>-preview-<branch>.<n>.
<branch> is the current git branch, for example main or new-better-command.

Uses the credential from \`dart pub token add ${REGISTRY}\`.
Set PUB_TOKEN (or QUIVER_TOKEN) only when that credential is not configured.

Example:
  melos run publish:quiver
EOF
}

# GNU sed accepts --version; the BSD sed shipped on macOS does not.
sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

# True when `dart pub token add` has already stored a credential for the registry.
# Pub normalizes the registry URL to end with a slash.
registry_has_token() {
  local listed line normalized
  listed="$(dart pub token list 2>/dev/null || true)"
  normalized="${REGISTRY%/}"
  while IFS= read -r line; do
    line="${line%/}"
    if [[ "$line" == "$normalized" ]]; then
      return 0
    fi
  done <<< "$listed"
  return 1
}

copy_package() {
  local package="$1"
  local dest="$2"
  local path rel count=0
  while IFS= read -r -d '' path; do
    # git ls-files --cached still lists files deleted in the working tree.
    if [[ ! -e "${ROOT}/${path}" && ! -L "${ROOT}/${path}" ]]; then
      continue
    fi
    rel="${path#packages/${package}/}"
    mkdir -p "${dest}/$(dirname "$rel")"
    cp -p "${ROOT}/${path}" "${dest}/${rel}"
    count=$((count + 1))
  done < <(git -C "$ROOT" ls-files -z --cached --others --exclude-standard -- "packages/${package}")
  if (( count == 0 )); then
    echo "No files found for packages/${package}." >&2
    exit 1
  fi
}

base_version() {
  local pubspec="$1"
  local raw
  raw="$(awk '/^version:/{print $2; exit}' "$pubspec")"
  if [[ -z "$raw" ]]; then
    echo "No version field in ${pubspec}" >&2
    return 1
  fi
  # Drop a pre-release or build suffix; the channel supplies a new one.
  printf '%s\n' "${raw%%[-+]*}"
}

# Channel for the current checkout: preview-<branch>.
# Characters that cannot appear in a semver pre-release identifier become hyphens.
channel_for_head() {
  local branch label
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    echo "Cannot publish from a detached HEAD. Check out a branch first." >&2
    return 1
  fi
  label="$(printf '%s' "$branch" | sed 's/[^0-9A-Za-z-]/-/g; s/^-*//; s/-*$//')"
  if [[ -z "$label" || "$label" =~ ^0[0-9]+$ ]]; then
    echo "Branch '${branch}' cannot be used in a version label." >&2
    return 1
  fi
  printf 'preview-%s\n' "$label"
}

# Highest build number already published for this channel, or -1 when none.
# Prints the number on stdout. Returns non-zero on registry or parse errors.
latest_build_number() {
  local marker="$1"
  local max=-1 package listing status n
  for package in "${PACKAGES[@]}"; do
    listing="$(mktemp)"
    status="$(curl -sS -o "$listing" -w "%{http_code}" \
      "${REGISTRY}/api/packages/${package}")" || {
      rm -f "$listing"
      echo "Failed to list the versions of ${package}" >&2
      return 1
    }
    if [[ "$status" == "404" ]]; then
      rm -f "$listing"
      continue
    fi
    if [[ "$status" != "200" ]]; then
      echo "Failed to list the versions of ${package}: ${status}" >&2
      cat "$listing" >&2 || true
      rm -f "$listing"
      return 1
    fi
    if ! n="$(jq --arg marker "$marker" \
      'if (.versions | type) != "array" then error("the response has no versions array")
       else [.versions[].version | select(contains($marker)) | split(".") | last | tonumber] | max // -1 end' \
      "$listing")"; then
      echo "Failed to read the versions of ${package}" >&2
      rm -f "$listing"
      return 1
    fi
    rm -f "$listing"
    if [[ ! "$n" =~ ^-?[0-9]+$ ]]; then
      echo "Unexpected build number for ${package}: ${n}" >&2
      return 1
    fi
    if (( n > max )); then
      max=$n
    fi
  done
  printf '%s\n' "$max"
}

prepare_pubspec() {
  local pubspec="$1"
  local version="$2"
  sed_inplace "s|^version:.*|version: ${version}|" "$pubspec"
  sed_inplace '/^resolution:[[:space:]]*workspace[[:space:]]*$/d' "$pubspec"
  if grep -q '^publish_to:' "$pubspec"; then
    sed_inplace "s|^publish_to:.*|publish_to: ${REGISTRY}|" "$pubspec"
  else
    printf '\npublish_to: %s\n' "$REGISTRY" >> "$pubspec"
  fi
  if ! grep -Fxq "version: ${version}" "$pubspec"; then
    echo "Failed to set the version in ${pubspec}" >&2
    exit 1
  fi
}

retarget_config_dependency() {
  local pubspec="$1"
  local config_version="$2"
  if ! grep -q '^  config:' "$pubspec"; then
    echo "cli_tools has no config dependency to retarget." >&2
    exit 1
  fi
  sed_inplace \
    "s|^  config: .*|  config: {hosted: ${REGISTRY}, version: ${config_version}}|" \
    "$pubspec"
  if ! grep -Fq "version: ${config_version}}" "$pubspec"; then
    echo "Failed to retarget the config dependency in cli_tools." >&2
    exit 1
  fi
}

cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "${WORKDIR:-}" ]]; then
    rm -rf "$WORKDIR"
  fi
  exit "$status"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  require_command curl
  require_command jq
  require_command git
  require_command dart

  if [[ -z "${PUB_TOKEN:-}" && -n "${QUIVER_TOKEN:-}" ]]; then
    export PUB_TOKEN="$QUIVER_TOKEN"
  fi

  local add_token_from_env=false
  if ! registry_has_token; then
    if [[ -z "${PUB_TOKEN:-}" ]]; then
      echo "No pub token is configured for ${REGISTRY}." >&2
      echo "Run: dart pub token add ${REGISTRY}" >&2
      echo "Or set PUB_TOKEN (or QUIVER_TOKEN)." >&2
      exit 1
    fi
    add_token_from_env=true
  fi

  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ ! -f "${ROOT}/packages/config/pubspec.yaml" || ! -f "${ROOT}/packages/cli_tools/pubspec.yaml" ]]; then
    echo "Expected packages/config and packages/cli_tools under ${ROOT}." >&2
    exit 1
  fi
  if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "This script must be run from the cli_tools git checkout." >&2
    exit 1
  fi

  local channel marker max suffix config_base cli_base config_version cli_version
  channel="$(channel_for_head)" || exit 1
  if [[ ! "$channel" =~ ^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$ ]]; then
    echo "Branch name produced an invalid version label: ${channel}" >&2
    exit 1
  fi
  marker="-${channel}."
  max="$(latest_build_number "$marker")" || exit 1
  suffix="${channel}.$((max + 1))"
  config_base="$(base_version "${ROOT}/packages/config/pubspec.yaml")" || exit 1
  cli_base="$(base_version "${ROOT}/packages/cli_tools/pubspec.yaml")" || exit 1
  config_version="${config_base}-${suffix}"
  cli_version="${cli_base}-${suffix}"

  echo "Publishing config ${config_version} and cli_tools ${cli_version} to ${REGISTRY}"

  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/publish-quiver.XXXXXX")"
  trap cleanup EXIT

  copy_package config "${WORKDIR}/config"
  copy_package cli_tools "${WORKDIR}/cli_tools"
  prepare_pubspec "${WORKDIR}/config/pubspec.yaml" "$config_version"
  prepare_pubspec "${WORKDIR}/cli_tools/pubspec.yaml" "$cli_version"
  retarget_config_dependency "${WORKDIR}/cli_tools/pubspec.yaml" "$config_version"

  echo "Publishing config..."
  if [[ "$add_token_from_env" == true ]]; then
    dart pub token add "$REGISTRY" --env-var PUB_TOKEN
  fi
  dart pub publish --force --directory "${WORKDIR}/config"
  echo "Publishing cli_tools..."
  dart pub publish --force --directory "${WORKDIR}/cli_tools"

  echo "Published config ${config_version} and cli_tools ${cli_version}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
