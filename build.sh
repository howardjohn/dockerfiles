#!/bin/bash

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

set -u

HUBS=""
TARGET="${TARGET:-all}"
DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"
REMOTE="${REMOTE:-0}"

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
    -r|--remote)
      REMOTE=1
      shift
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
    *) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      echo "  -n|--dry-run: do not build or push" >&2
      echo "  -f|--force: build even if there are no changes" >&2
      echo "  -r|--remote: push to remote" >&2
      echo "  -t|--target: (repeated) target to push" >&2
      exit 1
      ;;
  esac
done

EXTRA=""
if [[ "${REMOTE}" == 1 ]]; then
  EXTRA="-f remote.hcl"
fi

_green='\e[0;32m'
_yellow='\e[0;33m'
_clr='\e[0m'
function yellow() {
  echo -e "$_yellow"$*"$_clr"
}
function green() {
  echo -e "$_green"$*"$_clr"
}

# image_exists returns 1 if the image is missing, 0 if present
function image_exists() {
  if [[ "${FORCE}" == 1 ]]; then
    return 1
  else
    crane manifest "${1:?image name}" &> /dev/null
  fi
}

definition="$(docker-buildx bake all --print --progress=none -f docker-bake.hcl $EXTRA)"
needed=()
for target in $(<<<$definition jq -r '.group.all.targets[]'); do
  if [[ "${TARGET}" != "${target}" && "${TARGET}" != "all" ]]; then
    continue
  fi
  images=($(<<<$definition jq -r ".target[\"${target}\"].tags[]"))
  for image in ${images[@]}; do
    image_exists "$image" &
  done
  need=0
  for image in ${images[@]}; do
    wait -n # Wait for one tasks
    res=$?
    if [[ $res -ne 0 && $need -eq 0  ]]; then # Image is missing... we need to build it
      needed+=("$target")
      yellow "Building ${target}"
      need=1
      # let remaining complete so our next exit wait works
    fi
  done
  [[ $need -eq 0 ]] && green "Skipping ${target}"
done


if [[ ${#needed[@]} == 0 ]]; then
  yellow "No images to build"
  exit 0
fi

if [[ "${DRY_RUN}" == 1 ]]; then
  yellow "Skipping build due to dry run"
  docker-buildx bake ${needed[@]} --print --progress=none -f docker-bake.hcl $EXTRA
  exit 0
fi

docker-buildx bake ${needed[@]} -f docker-bake.hcl $EXTRA

