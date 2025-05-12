#!/usr/bin/env bash
# multipath test script and command line utility
# Author:  <qinwang@redhat.com>
#

USAGE="Usage: $0 < -m mpath> < -c testcase> [-o other args] 
[-t timout] [-i interval] [-l log file] [-n avaliable path number] 

  -m mpath:  The multipath name, e.g. mpatha
  -c case :  Testcase index, 0-9, 
      0: Display multipath
         ==Offline Mode==
      1: Switch once 
      2: Loop Switch [loop number, default is 1000000]
      3: Enable all paths
      4: Disable all paths
         ==Iptables Mode==
      5: Switch once 
      6: Loop Switch [loop number,default is 1000000]
      7: Enable all paths
      8: Disable all paths

      9: Self-Defined Function Test

  -o other args: the test parameters or functions test
  -t timeout:  Timeout for switch, default 180s
  -i interval: Interval of each switch, default 5s
  -n avaliable paths number:   Trigger to enable other paths if the avaliable paths
               less than or equal to the vaule. Default 1.
  -l log file: The path of log file. Default is under current logs folder


  Example: 
  # unlimited loop switch with default timeout and interval
  $0 -m mpatha -c 2 

  # loop switch 3 times with timeout 300 and interval 3
  $0 -m mpatha -c 2 -t 300 -i 5 -o 3

  # call mp_loop_switch with default timeout,interval. mode is onoff and loop is 2
  # $0 -m mpatha -c 9 -o \"mp_loop_switch 'onoff' 2\"
"

# Default
MPATH=
TESTCASE=0
TIMEOUT=180
INTERVAL=5
OTHER_ARGS=
NUM_AVALIABLE_PATHS=1

DEFAULT_LOGDIR="$(dirname $0)/logs"
LOGDIR=${LOGDIR:-$DEFAULT_LOGDIR}
LOGFILE="$LOGDIR/$(basename $0 .sh)-$(date +%F-%H%M%S).log"

mp_info() {
  echo "$@"
}

mp_cmd() {
  echo "$@"
  eval "$@"
  return $?

}

while getopts "hm:n:c:t:i:o:l:" opt; do
  case $opt in
  h)
    echo -e "$USAGE"
    exit 0
    ;;
  m)
    MPATH="$OPTARG"
    ;;
  n)
    NUM_AVALIABLE_PATHS="$OPTARG"
    ;;
  c)
    TESTCASE="$OPTARG"
    ;;
  t)
    TIMEOUT="$OPTARG"
    ;;
  i)
    INTERVAL="$OPTARG"
    ;;
  o)
    OTHER_ARGS="$OPTARG"
    ;;
  l)
    LOGFILE="$OPTARG"
    ;;
  ? | *)
    echo -e "$USAGE"
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done

# Handle log
if [ ! -d "$(dirname $LOGFILE)" ]; then
  mkdir -p "$(dirname $LOGFILE)"
fi

LOGLINK=$(dirname "$LOGFILE")/$(basename "$0" .sh)-latest.log
mp_cmd ln -srf "${LOGFILE}" "${LOGLINK}"
echo "Logging to ${LOGFILE} ${LOGLINK}"


if [[ -z "$MPATH" || -z "$TESTCASE" ]]; then
  echo -e "Missing parameter or Wrong case.\n$USAGE\n"
  exit 1
fi

MP_PATHS=$(sudo multipath -ll "${MPATH}" | grep -o 'sd[a-z]' | sort -u | tr '\n' ' ')
if [ -z "${MP_PATHS}" ]; then
  echo "Wrong mpath: ${MPATH} no path be found."
  exit 1
fi

exec &> >(tee >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush() }' >"${LOGFILE}"))

echo -e "Test ${MPATH}: ${MP_PATHS}
Testcase: ${TESTCASE} Timeout: ${TIMEOUT} Interval: ${INTERVAL} 
Avaliable paths: $NUM_AVALIABLE_PATHS Other: ${OTHER_ARGS} Logfile: ${LOGFILE} 
"

mp_wait_for() {
  local cmd="$1"                   # command
  local timeout=${2:-$TIMEOUT}     # timeout(default 60S)
  local interval=${3:-$INTERVAL}   # interval (default 60S)
  local fail_msg=${4:-"Timeout"}   # message
  local show_progress=${5:-"true"} #
  local wait_msg=${6:-""}          #

  local elapsed=0
  if [ -n "$wait_msg" ]; then
    mp_info "Wait for $wait_msg"
  else
    mp_info "Wait for $cmd"
  fi
  while ! eval "$cmd"; do
    sleep "$interval"
    elapsed=$((elapsed + interval))

    if [ "$show_progress" = "true" ]; then
      echo -n "."
    fi

    if [ "$elapsed" -ge "$timeout" ]; then
      if [ "$show_progress" = "true" ]; then
        echo " "

      fi
      echo "$fail_msg timeout after ${timeout}s"
      return 1
    fi
  done
  echo -e "\nWait $wait_msg end($(date "+%H:%M:%S")) time:$elapsed"

  return 0
}

mp_get_mpath_devices() {
  sudo multipath -ll "${MPATH}" | grep -o 'sd[a-z]' | sort -u
  # lsblk -s /dev/mapper/${MPATH}|grep "─"|grep -o 'sd[a-z]'|sort -u
}

mp_get_device_mpath() {
  lsblk /dev/"$1" | grep -o 'mpath[a-z]'
}

get_iscsi_portal_by_device() {
  local dev=${1}
  local portal
  portal=$(ls -l /dev/disk/by-path | grep iscsi | grep ${dev} | cut -f 2 -d "-")
  if [ -n "$portal" ]; then
    portal=$(echo "$portal" | cut -f 1 -d ":")
    echo "$portal"
  else
    return 1
  fi

}

mp_onoff_disable_path() {
  local dev=$1
  echo "Disable ===== ${dev} $(date "+%H:%M:%S")"
  mp_cmd "echo offline > /sys/block/${dev}/device/state"
}

mp_onoff_enable_path() {
  local dev=$1
  echo "Enable ===== ${dev} $(date "+%H:%M:%S")"
  mp_cmd "echo running > /sys/block/${dev}/device/state"
}

mp_iptables_disable_path() {
  local dev=$1
  local portal=${2:-$(get_iscsi_portal_by_device "$dev")}
  echo "Disable ===== ${dev} $(date "+%H:%M:%S")"
  # mp_cmd iptables -A INPUT -s "${portal}" -j DROP
  if ! nft list table inet filter >/dev/null; then
    nft add table inet filter
    nft add chain inet filter input { type filter hook input priority 0\; policy accept\; }
  fi
  mp_cmd nft add rule inet filter input ip saddr "${portal}" drop

}

mp_iptables_enable_path() {
  local dev=$1
  local portal
  portal=${2:-$(get_iscsi_portal_by_device "$dev")}
  echo "Enable ===== ${dev} $(date "+%H:%M:%S")"
  # mp_cmd iptables -D INPUT -s "${portal}" -j DROP

  handle=$(nft --handle list chain inet filter input | grep -n "ip saddr ${portal} drop" | grep -o 'handle [0-9]*' | awk '{print $2}')

  if [[ -z "$handle" ]]; then
    echo "No DROP rule for IP ${portal} found in inet filter input."
    return
  fi

  mp_cmd nft delete rule inet filter input handle "$handle"

}

mp_get_active_paths() {
  sudo multipath -ll "${MPATH}" | grep "status=active" -A 1 | grep -E "active .* running" | grep -o 'sd[a-z]' | sort -u

}

mp_get_failed_paths() {
  dev=${1:-""}
  if [ -n "$dev" ]; then
    sudo multipath -ll "${MPATH}" | grep -E "failed " | grep -o 'sd[a-z]' | sort -u | grep $dev
  else
    sudo multipath -ll "${MPATH}" | grep -E "failed " | grep -o 'sd[a-z]' | sort -u
  fi

}

mp_get_avaliable_paths() {
  dev=${1:-""}
  if [ -n "$dev" ]; then
    mp_cmd sudo multipath -ll "${MPATH}" | grep -E "active .* running" | grep -o 'sd[a-z]' | sort -u | grep $dev
  else
    mp_cmd sudo multipath -ll "${MPATH}" | grep -E "active .* running" | grep -o 'sd[a-z]' | sort -u
  fi
}

mp_get_avaliable_paths_num() {
  sudo multipath -ll "${MPATH}" | grep -E "active .* running" | grep -o 'sd[a-z]' | sort -u | wc -l
}

mp_enable_path() {
  local dev=${1}
  local mode=${2:-"onoff"}
  if [ "$mode" == "iptables" ]; then
    mp_iptables_enable_path "${dev}"
  else
    mp_onoff_enable_path "${dev}"
  fi
  mp_wait_for "mp_get_avaliable_paths $dev" ${TIMEOUT} 2 "Can not enable $dev" "" "enable $dev"
}

mp_disable_path() {
  local dev=${1}
  local mode=${2:-"onoff"}
  if [ "$mode" == "iptables" ]; then
    mp_iptables_disable_path "${dev}"
  else
    mp_onoff_disable_path "${dev}"
  fi
  mp_wait_for "mp_get_failed_paths $dev" 120 2 "Can not disable $dev" "" "disable $dev"
}

mp_enable_all_paths() {
  local mode=${1:-"onoff"}
  local devs
  devs=$(mp_get_failed_paths "")
  if [ -n "${devs}" ]; then
    echo "Ready to enable the failed paths: " ${devs}
    for dev in $devs; do
      mp_enable_path "${dev}" "${mode}"
    done
  fi
}

mp_disable_all_paths() {
  local mode=${1:-"onoff"}
  local devs
  devs=$(mp_get_avaliable_paths "")
  if [ -n "${devs}" ]; then
    echo "Ready to disable avaliable paths: " ${devs}
    for dev in ${devs}; do
      mp_disable_path "${dev}" "${mode}"
    done
  fi
}

mp_switch() {
  local devs num dev old_dev new_dev
  echo -e "\n======== $(date "+%H:%M:%S")\n"
  multipath -ll "${MPATH}"
  mode=${1}
  # Ensure at least two path are avaliable
  devs=$(mp_get_avaliable_paths "")
  num=$(mp_get_avaliable_paths_num)
  if ((num > NUM_AVALIABLE_PATHS)); then
    echo "Skip enable due to have ${num} enabled paths:" ${devs}
  else
    echo "Enabled paths due to have ${num} enabled paths:" ${devs} "(need > $NUM_AVALIABLE_PATHS)"
    mp_enable_all_paths "${mode}"

    echo "After Enable " ${devs}
    multipath -ll "${MPATH}"
  fi

  # Ensure at least one path is active
  mp_wait_for 'old_dev=$(mp_get_active_paths);[ -n "${old_dev}" ]' "" "" "" "No active" "checking active"

  if [ -n "${old_dev}" ]; then
    mp_disable_path "${old_dev}" "$mode"
  fi

  # Wait new path become active
  mp_wait_for 'new_dev=$(mp_get_active_paths);[ -n "${new_dev}" ] && [ "${new_dev}" != "${old_dev}" ]' $TIMEOUT $INTERVAL "Can not find new active path" "" "new active path"

  [ $? -ne 0 ] && {
    echo "Switch failed timeout. Any IO one the ${MPATH}?"
    exit 1
  }
  echo "Switch the active path from [ ${old_dev} ] to [ ${new_dev} ] $(date "+%H:%M:%S")"
  multipath -ll "${MPATH}"

}

mp_loop_switch() {
  local mode=${1}
  local loop=${2:-1000000}
  local interval=${3:-"${INTERVAL}"}
  mp_info "Start Loop Switch: mode:${mode} loop:${loop} interval:${interval}"
  for ((idx = 0; idx < loop; idx++)); do
    mp_info "Loop Switch Iteration: $idx"
    mp_switch "$mode"
    [ $? -ne 0 ] && {
      echo "Switch failed, exit"
      exit 1
    }

    sleep "${interval}"
  done
  mp_info "Finish Loop Switch: mode:${mode} loop:${loop} interval:${interval}"
}

mp_service_restart() {
  # Record only relevant services
  echo " 
  systemctl stop multipathd.service multipathd.socket;  sleep 3;  systemctl start multipathd;  systemctl reload --now multipathd; 
  
  systemctl enable qemu-pr-helper;systemctl start qemu-pr-helper;  systemctl status qemu-pr-helper
  
  "

}

mp_version() {

  rpm -q device-mapper device-mapper-multipath
  uname -r
}

case ${TESTCASE} in
0)
  echo "Display multipath ..."
  multipath -ll "${MPATH}"
  ;;
1)
  echo "Switch once by offline..."
  mp_switch "onoff"
  ;;
2)
  echo "Loop Switch by offline..."
  mp_loop_switch "onoff" "${OTHER_ARGS}"
  ;;
3)
  echo "Enable all paths ..."
  mp_enable_all_paths "onoff"
  ;;
4)
  echo "Disable all paths ..."
  mp_disable_all_paths "onoff"
  ;;
5)
  echo "Switch once by iptables..."
  mp_switch "iptables"
  ;;
6)
  echo "Loop Switch by iptables..."
  mp_loop_switch "iptables" "${OTHER_ARGS}"
  ;;
7)
  echo "Enable all paths by iptables..."
  mp_enable_all_paths "iptables"
  ;;
8)
  echo "Disable all paths by iptables..."
  mp_disable_all_paths "iptables"
  ;;
9)
  echo "Function $OTHER_ARGS..."
  mp_cmd "$OTHER_ARGS"
  ;;

? | *)
  echo "Wrong Usage"
  echo -e "$USAGE"
  exit 1 #
  ;;

esac
