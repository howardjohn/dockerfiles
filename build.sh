#!/bin/bash

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

set -eu

OUT="build/docker-bake.hcl"
rm -f "${OUT}"
mkdir -p "build/"
touch "${OUT}"
HUBS=""
TARGET="${TARGET:-all}"
DRY_RUN="${DRY_RUN:-0}"
PARAMS=""
FORCE="${FORCE:-0}"

while (( "$#" )); do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -h|--hub)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        HUBS+=" $2"
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -t|--target)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        TARGET=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

HUBS="${HUBS:-localhost:5000}"

_red='\e[0;31m'
_green='\e[0;32m'
_yellow='\e[0;33m'
_clr='\e[0m'
function yellow() {
  echo -e "$_yellow"$*"$_clr"
}
function green() {
  echo -e "$_green"$*"$_clr"
}
function red() {
  echo -e "$_red"$*"$_clr"
}

function check_image_exits() {
  if [[ "${FORCE}" == 1 ]]; then
    return 0
  else
    ! crane manifest "${1:?image name}" &> /dev/null
  fi
}

function fetch_tags() {
  name="${1:?name}"
  if [ -f "${name}/settings" ]; then
    version=$(grep VERSION= "${name}/settings" | cut -d= -f2)
    tags=$(grep TAGS= "${name}/settings" | cut -d= -f2)
    echo "$version $tags"
  else
    echo "latest"
  fi
}

function fetch_version() {
  name="${1:?name}"
  if [ -f "${name}/settings" ]; then
    version=$(grep VERSION= "${name}/settings" | cut -d= -f2)
    echo "$version"
  fi
}

function missing_images() {
  name="${1:?name}"
  tags=""
  tags="$(fetch_tags "${name}")"
  primary="$(echo $tags | cut -d' ' -f1)"
  for hub in ${HUBS}; do
    if check_image_exits "${hub}/${name}:${primary}"; then
      for tag in ${tags}; do
        echo "${hub}/${name}:${tag}"
      done
    fi
  done
}

function wrap_quotes() {
  items="${1:?items}"
  result=""
  for item in ${items}; do
    result+="\"${item}\" "
  done
  echo "${result}" | tr ' ' ','
}

function tags_to_image_list() {
  name="${1:?name}"
  tags="${2:?tags}"
  result=""
  for hub in ${HUBS}; do
    for tag in ${tags}; do
      result+="${hub}/${name}:${tag} "
    done
  done
  wrap_quotes "${result}"
}

function generate_bake() {
  name="${1:?name}"
  tags="${2:?tags}"
  version="${3:?version}"
  cat <<EOF >> "${OUT}"
target "${name}" {
    tags = [$(wrap_quotes "${tags}")]
    args = {
      BUILDKIT_INLINE_CACHE = "1"
      VERSION = "${version}"
    }
    context = "${name}"
    platforms = [
        "linux/amd64",
        "linux/arm64",
    ]
    output = ["type=registry"]
}
EOF
}

function generate_bake_group() {
  names="${1?names}"

  cat <<EOF >> "${OUT}"
  group "all" {
    targets = [$(wrap_quotes "${names}")]
  }
EOF
}

function generate() {
  targets=""
  for dir in */; do
    name="${dir%/}"
    if [[ "${TARGET}" != "${name}" && "${TARGET}" != "all" ]]; then
      continue
    fi
    if [ -f "${name}/Dockerfile" ]; then
      images="$(missing_images "${name}")"
      if [[ "${images}" == "" ]]; then
        yellow "Skipping \"${name}\""
        continue
      fi
      version="$(fetch_version "${name}")"
      targets+="${name} "
      green "Building image \"${name}\" version: ${version}"
      generate_bake "${name}" "${images}" "${version}"
    fi
  done
  if [[ "${targets}" == "" ]]; then
    yellow "No targets to build"
    return 1
  fi
  generate_bake_group "${targets}"
}

generate || exit
if [[ "${DRY_RUN}" == 1 ]]; then
  yellow "Skipping build due to dry run"
  exit 0
fi
if [[ -f build/docker-bake.hcl ]]; then
  docker buildx bake -f build/docker-bake.hcl "${TARGET}"
fi
