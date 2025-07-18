#!/bin/bash

set -eu

_blue='\e[0;34m'
_red='\e[0;31m'
_green='\e[0;32m'
_yellow='\e[0;33m'
_clr='\e[0m'
function yellow() {
  >&2 echo -e "$_yellow"$*"$_clr"
}
function green() {
  >&2 echo -e "$_green"$*"$_clr"
}
function red() {
  >&2 echo -e "$_red"$*"$_clr"
}
function blue() {
  >&2 echo -e "$_blue"$*"$_clr"
}
function debug() {
  >&2 echo -e "$*"
}

function to_ms() {
  stdin="$(cat -)"
  if [[ "${stdin}" == "" ]]; then
    echo "-"
  else
    python3 -c "print(\"%.03fms\" % (${stdin}*1000))"
  fi
}

function fmt_qps() {
  stdin="$(cat -)"
  if [[ "${stdin}" == "" ]]; then
    echo "-"
  else
    python3 -c "print(\"%.02fqps\" % ${stdin})"
  fi
}

function help() {
  cat <<EOF
benchmark runs various load generators with varying settings.

All options listed below can pass a single value, or a comma separated value.

Example: benchmark --qps 10,100 --connections 64 http://localhost:8080 | column -ts,
Example (multiple destination with alias): benchmark http://some-long-name/target-default#default,http://some-long-name/target-test#test  | column -ts,

Options:
  -c, --connections   Number of connections to open
  -q, --qps           Number of requests per second
  -d, --duration      Number of seconds to run for
  -t, --tool          Tool to use. Valid options are fortio,hey,oha,nighthawk,wrk
  -b, --burst         Send requests in bursts.
  -p, --payload       Payload size (only fortio)
EOF
}

# Default values of arguments
CONNECTIONS=16
QPS=500
DURATION=5
DESTINATION=""
JITTER="true"
VERBOSE=""
PAYLOAD=0
TOOL=fortio

RESULTS_DIR="${RESULTS_DIR:-/tmp/results}"
mkdir -p "${RESULTS_DIR}"

# Loop through arguments and process them
while (( "$#" )); do
  case "$1" in
    -c|--connections)
    CONNECTIONS="$2"
    shift
    shift
    ;;
    -q|--qps)
    QPS="$2"
    shift
    shift
    ;;
    -d|--duration)
    DURATION="$2"
    shift
    shift
    ;;
    -t|--tool)
    TOOL="$2"
    shift
    shift
    ;;
    -p|--payload)
    PAYLOAD="$2"
    shift
    shift
    ;;
    -b|--burst)
    JITTER="false"
    shift
    ;;
    -v|--verbose)
    VERBOSE="true"
    shift
    ;;
    -h|--help)
    help
    exit 0
    ;;
    *)
    DESTINATION="$1"
    shift
    ;;
  esac
done

blue "# Connections: $CONNECTIONS"
blue "# Duration: $DURATION"
blue "# QPS: $QPS"
blue "# Destination: ${DESTINATION}"
blue "# Payload: ${PAYLOAD}"
blue "# Results: ${RESULTS_DIR}"
blue "# Jitter: ${JITTER}"
blue "# Tool: ${TOOL}"

if [[ "${DESTINATION}" == "" ]]; then
  red "Destination is not set"
  exit 1
fi

function fail() {
  output="${1}"
  >&2 echo "COMMAND FAILED"
  >&2 cat "${RESULTS_DIR}/${output}.log"
  exit 1
}

function run() {
  output="${1}"
  if [[ "${VERBOSE}" == "true" ]]; then
    debug "Running: $@"
  fi
  if [[ "${VERBOSE}" == "true" ]]; then
    $@ > >(tee "${RESULTS_DIR}/${output}" >&2) 2> >(tee "${RESULTS_DIR}/${output}.log" >&2) || fail "${output}"
  else
    $@ > "${RESULTS_DIR}/${output}" 2> "${RESULTS_DIR}/${output}.log" || fail "${output}"
  fi
}

function run_benchmark() {
  tool="$1"
  qps="$2"
  dur="$3"
  cons="$4"
  payload="$5"
  destName="$(echo $6 | cut -d# -f2-)"
  dest="$(echo $6 | cut -d# -f1)"
  green "Running $tool to $destName at $qps QPS for ${dur}s and ${cons} connections..."
  case "$tool" in
  fortio)
    rm -f "${RESULTS_DIR}/fortio" &> /dev/null
    run fortio load -uniform="${JITTER}" -qps "${qps}" -t "${dur}"s -c "${cons}" -payload-size "${payload}" -httpccch -json "${RESULTS_DIR}"/fortio.json -r 0.000001 "${dest}"
    req=$(< "${RESULTS_DIR}"/fortio.json jq -r '.RetCodes."200"')
    throughput=$(< "${RESULTS_DIR}"/fortio.json jq '.ActualQPS' | fmt_qps)
    p50=$(< "${RESULTS_DIR}"/fortio.json jq '.DurationHistogram.Percentiles[] | select(.Percentile == 50).Value' | to_ms)
    p90=$(< "${RESULTS_DIR}"/fortio.json jq '.DurationHistogram.Percentiles[] | select(.Percentile == 90).Value' | to_ms)
    p99=$(< "${RESULTS_DIR}"/fortio.json jq '.DurationHistogram.Percentiles[] | select(.Percentile == 99).Value' | to_ms)
    ;;
  hey)
    run hey -q "$((${qps}/${cons}))" -z "${dur}"s -c "${cons}" "${dest}"
    req=$(< "${RESULTS_DIR}"/hey grep '\[200\]' | cut -d$'\t' -f2 | cut -d' ' -f1)
    throughput=$(< "${RESULTS_DIR}"/hey grep 'Requests' | cut -f2 | fmt_qps)
    p50=$(< "${RESULTS_DIR}"/hey grep '50%' | cut -d' ' -f5 | to_ms)
    p90=$(< "${RESULTS_DIR}"/hey grep '90%' | cut -d' ' -f5 | to_ms)
    p99=$(< "${RESULTS_DIR}"/hey grep '99%' | cut -d' ' -f5 | to_ms)
    ;;
  oha)
    # Oha doesn't support qps==0, unset is as fast as possible
    OHA_QPS="-q ${qps}"
    if [[ "${qps}" == 0 ]]; then
      OHA_QPS=""
    fi

    run oha --no-tui ${OHA_QPS} -z "${dur}"s -c "${cons}" "${dest}"
    req=$(< "${RESULTS_DIR}"/oha grep '\[200\]' | cut -d' ' -f 4)
    throughput=$(< "${RESULTS_DIR}"/oha grep 'Requests' | cut -f2 | fmt_qps)
    p50=$(< "${RESULTS_DIR}"/oha grep '50.00%' | cut -d' ' -f5 | to_ms)
    p90=$(< "${RESULTS_DIR}"/oha grep '90.00%' | cut -d' ' -f5 | to_ms)
    p99=$(< "${RESULTS_DIR}"/oha grep '99.00%' | cut -d' ' -f5 | to_ms)
    ;;
  nighthawk)
    # Nighthawk doesn't support qps==0, set to high number
    NIGHTHAWK_QPS="--rps ${qps}"
    if [[ "${qps}" == 0 ]]; then
      NIGHTHAWK_QPS="--rps 1000000"
    fi
    jitter=""
    if [[ "${JITTER}" == "false" ]]; then
      j=$(python3 -c 'print(f"{float(0.1 * 1 / '$qps'):.9f}")')
      jitter="--jitter-uniform ${j}s"
    fi
    run nighthawk ${NIGHTHAWK_QPS} --connections "${cons}" ${jitter} --duration "${dur}" --concurrency "${payload}" "${dest}" --output-format fortio --prefetch-connections
    req=$(< "${RESULTS_DIR}"/nighthawk jq -r '.RetCodes."200"')
    throughput=$(< "${RESULTS_DIR}"/nighthawk jq '.ActualQPS' | fmt_qps)
    p50=$(< "${RESULTS_DIR}"/nighthawk jq '.DurationHistogram.Percentiles[] | select(.Percentile == 50).Value' | to_ms)
    p90=$(< "${RESULTS_DIR}"/nighthawk jq '.DurationHistogram.Percentiles[] | select(.Percentile == 90).Value' | to_ms)
    p99=$(< "${RESULTS_DIR}"/nighthawk jq '.DurationHistogram.Percentiles[] | select(.Percentile == 99).Value' | to_ms)
    ;;
  wrk)
    # wrk doesn't support qps==0, set to high number
    WRK_QPS="--rate ${qps}"
    if [[ "${qps}" == 0 ]]; then
      WRK_QPS="--rate 10000000"
    fi

    # Add http:// if dest does not start with http:// or https://
    if [[ ! "${dest}" =~ ^https?:// ]]; then
      dest="http://${dest}"
    fi
    threads=$(($(nproc) < ${cons} ? $(nproc) : ${cons}))
    run wrk ${WRK_QPS} --connections "${cons}" --threads "${threads}" --duration "${dur}"s -L "${dest}"
    req=$(< "${RESULTS_DIR}"/wrk grep 'requests in' | xargs | cut -d' ' -f1)
    throughput=$(< "${RESULTS_DIR}"/wrk grep Requests/sec: | tr -s ' ' | cut -d' ' -f2 | fmt_qps)
    p50=$(< "${RESULTS_DIR}"/wrk grep '50.000%' | tr -s ' ' | cut -d' ' -f3)
    p90=$(< "${RESULTS_DIR}"/wrk grep '90.000%' | tr -s ' ' | cut -d' ' -f3)
    p99=$(< "${RESULTS_DIR}"/wrk grep '99.000%' | tr -s ' ' | cut -d' ' -f3)
    ;;
  *)
    red "Unknown tool $tool"
    exit 1
    ;;
  esac
  debug "qps: $throughput\tp50: $p50\tp90: $p90\tp99: $p99"
  echo "$destName,$tool,$qps,$cons,$dur,$payload,$req,$throughput,$p50,$p90,$p99"
}


results=""
for cons in ${CONNECTIONS//,/ }; do
  for dur in ${DURATION//,/ }; do
    for qps in ${QPS//,/ }; do
      for payload in ${PAYLOAD//,/ }; do
        for tool in ${TOOL//,/ }; do
          for destination in ${DESTINATION//,/ }; do
            res="$(run_benchmark $tool $qps $dur $cons $payload $destination)"
            results+="${res}\n"
          done
        done
      done
    done
  done
done

{
  echo "DEST,CLIENT,QPS,CONS,DUR,PAYLOAD,SUCCESS,THROUGHPUT,P50,P90,P99"
  echo -e "$results"
} | column -ts,