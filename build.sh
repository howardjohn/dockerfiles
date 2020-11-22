#!/bin/bash

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

set -eu

OUT="build/docker-bake.hcl"
rm -f "${OUT}"
HUB="${HUB:-localhost:5000}"
TARGET="${TARGET:-all}"
DRY_RUN="${DRY_RUN:-0}"

while (( "$#" )); do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--hub)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        HUB=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -t|--taregt)
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
  return docker manifest inspect "${1:?image name}" --insecure &> /dev/null
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

function missing_tags() {
  name="${1:?name}"
  tags=""
  tags="$(fetch_tags "${name}")"
  primary="$(echo $tags | cut -d' ' -f1)"
  if ! docker manifest inspect "${HUB}/${name}:${primary}" --insecure &> /dev/null; then
    echo "${tags}"
  fi
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
  for tag in ${tags}; do
    result+="${HUB}/${name}:${tag} "
  done
  wrap_quotes "${result}"
}

function generate_bake() {
  name="${1:?name}"
  tags="${2:?tags}"
  cat <<EOF >> "${OUT}"
target "${name}" {
    tags = [$(tags_to_image_list "${name}" "${tags}")]
    args = {}
    context = "${name}"
    platforms = [
        "linux/amd64",
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
    if [ -f "${name}/Dockerfile" ]; then
      tags="$(missing_tags "${name}")"
      if [[ "${tags}" == "" ]]; then
        yellow "Skipping \"${name}\""
        continue
      fi
      targets+="${name} "
      green Building image \"${name}\" tags: "${tags}"
      generate_bake "${name}" "${tags}"
    fi
  done
  if [[ "${targets}" == "" ]]; then
    yellow "No targets to build"
    return
  fi
  generate_bake_group "${targets}"
}

generate
if [[ "${DRY_RUN}" == 1 ]]; then
  yellow "Skipping build due to dry run"
  exit 0
fi
if [[ -f build/docker-bake.hcl ]]; then
  docker buildx bake -f build/docker-bake.hcl "${TARGET}"
fi
