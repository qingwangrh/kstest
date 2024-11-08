#!/bin/bash

# if [ -n "$SVG_COMMON_SOURCED" ]; then
#   return
# fi
# echo "Enter $0"
# export SVG_COMMON_SOURCED=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DISABLE_COLOR='\033[0m' # Disable Color

function kslog_set_log() {
  # parameter: logfile reset
  LOG_FILE=$1
  # empty log
  [[ "$2" == "1" ]] && {
    echo "Reset ${LOG_FILE}"
    echo "" >${LOG_FILE}
  }

}
function kslog_get_log() {
  return ${LOG_FILE}
}

function kslog_rotate_log() {
  # logfile rotate
  file=${1:-$LOG_FILE}
  if [ -e ${file} ]; then
    local fname fdir stamp sptfile record
    fname=$(basename ${file})
    fdir=$(dirname ${file})
    stamp=$(date '+%m-%d-%H:%M:%S')
    sptfile="${fdir}/$fname.$stamp.part"
    record="${fdir}/$fname.spt"
    echo "$sptfile" | tee -a ${record}
    mv ${file} "$sptfile"
    # clear file with magic code
    echo "- -- --- ---- ${stamp}" >${file}
  fi

}
function kslog_merge_log() {
  # logfile rotate
  file=${1:-$LOG_FILE}
  if [ -e ${file} ]; then
    local fname fdir stamp sptfile record
    fname=$(basename ${file})
    fdir=$(dirname ${file})
    record="${fdir}/$fname.spt"
    if [ -e ${record} ]; then
      cat $(cat ${record}) ${file} >/tmp/${fname}
      mv "${file}" "${file}.$(date '+%m-%d-%H:%M:%S').sav"
      mv /tmp/${fname} "${file}"
      mv ${record} ${record}.sav
    else
      echo "Can not find $record, Skip merge log."
    fi
  fi

}

function kslog_color() {
  printf "$1"
  shift
  printf "$(date '+%m-%d %H:%M:%S') | $*\n" | tee -a ${LOG_FILE}
  printf "${DISABLE_COLOR}"
}

function kslog_error {
  kslog_color "${RED}" "$@"
}

function kslog_info {
  kslog_color "${GREEN}" "$@"
}

function kslog_warn {
  kslog_color "${YELLOW}" "$@"
}

function _exit_on_error() {
  owner=$0
  ret=$1
  msg=$2
  # set -xv
  if [ $1 -ne 0 ]; then
    shift
    kslog_error "$@"
    echo "--$owner $ret"
    if [[ "$owner" == "-bash" ]]; then
      return $ret
    else
      echo "xxx"
      exit $ret
    fi
  fi
}

function _warn_on_error() {
  if [ $1 -ne 0 ]; then
    shift
    kslog_warn "$@"
  fi
}

svg_version() {
  kslog_info "$({
    cat /etc/redhat-release
    uname -r
    rpm -q lvm2
  })"

}

svg_help() {
  echo -e "
   #init

   yum install -y lvm2-lockd sanlock;
   systemctl enable wdmd sanlock lvmlockd
   systemctl start wdmd sanlock lvmlockd
   systemctl restart wdmd sanlock lvmlockd

    cat <<EOF | sudo tee /etc/modules-load.d/kubesan.conf
nbd
dm-thin-pool
EOF


   -> /etc/lvm/lvm.config:
   io_memory_size = 32768, use_lvmlockd = 1, archive = 0, backup=0
   -> /etc/lvm/lvmlocal.conf:
   host_id = unique id
   -> /etc/sanlock/sanlock.conf:
   use_watchdog = 0

   #create vg (init)
       lvmdevices --devicesfile myvg --adddev /dev/sdb

     # check if sanlock and lvmlockd are configured correctly
       vgchange --devicesfile myvg --lock-start
  # del dev
     lvmdevices --devicesfile myvg --deldev /dev/sdb
root@dell-per750-15 /home $ cat  /etc/lvm/devices/myvg
     # make sure the vg is visible
       vgs --devicesfile my-vg my-vg

   # if reboot need recreate global lock
   vgchange --lock-start
   "
}

svg_cmd_time() {
  local start_time end_time
  start_time=$(date +%s)
  kslog_info "CMD: $1"
  eval "$1"
  ret=$?
  end_time=$(date +%s)
  kslog_info "Time $2: $((end_time - start_time)) "
  return $ret
}

svg_cmd() {
  kslog_info "CMD: $@"
  eval "$@"
  ret=$?
  return $ret
}

svg_cmd_exit() {
  # set -e
  svg_cmd_time "$@"
  ret=$?
  _exit_on_error $ret "$@"
  return $ret
  # if [ $ret -ne 0 ]; then
  #   kslog_error "Error($ret) on $@"
  #   exit $ret
  # fi
}

svg_cmd_warn() {
  svg_cmd_time "$@"
  ret=$?
  if [ $ret -ne 0 ]; then
    kslog_warn "Error($ret) on $@"
  fi
  return $ret
}

svg_vg_create() {
  local OPT OPTARG OPTIND
  local usage vgname devs metadatasize opts
  usage="${FUNCNAME} <-v vgname> <-d LUNS> [-o opts] [-m metadatasize]"

  while getopts 'v:d:m:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    d)
      devs="$OPTARG"
      ;;
    m)
      metadatasize="$OPTARG"
      ;;
    o)
      opts="$OPTARG"
      ;;
    ? | h)
      kslog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  devs=${devs:-"${LUNS}"}
  metadatasize=${metadatasize:-${METADATA_SIZE}}

  if [ -z "${vgname}" ] || [ -z "${devs}" ]; then
    kslog_error "${usage}, Miss parameter !"
    return 1
  fi

  if vgs --devicesfile $vgname $vgname; then
    kslog_warn "Already exist $vgname,skip creating $vgname"
    svg_cmd_exit "vgchange --devicesfile $vgname --lock-start"
    return
  fi
  for dev in ${devs}; do
    svg_cmd_exit "lvmdevices --devicesfile $vgname --adddev $dev"
  done
  if vgs --devicesfile $vgname $vgname; then
    kslog_warn "Already exist $vgname,skip creating $vgname"

  else
    svg_cmd_exit "vgcreate --shared $vgname ${devs} --config global/sanlock_align_size=2 --metadatasize ${metadatasize} ${opts}"
  fi
  svg_cmd_exit "vgchange --devicesfile $vgname --lock-start"
  svg_cmd_exit "vgs --devicesfile $vgname $vgname"
  svg_cmd_exit "vgdisplay --devicesfile $vgname -C -o name,mda_size,mda_free $vgname"

}

svg_vg_remove() {
  local OPT OPTARG OPTIND
  local usage vgname devs dev
  usage="${FUNCNAME} <-v vgname> "

  while getopts 'v:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    ? | h)
      kslog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}

  if [ -z "${vgname}" ]; then
    kslog_error "${usage}, Miss parameter !"
    return 1
  fi

  if svg_cmd "vgs --devicesfile $vgname $vgname"; then
    devs=$(
      pvs --devicesfile $vgname | awk -v vgname="$vgname" '{if ($2 == vgname) { print $1 }} '
    )

    # fast method: vgchange -an ,lockstop,wipefs
    svg_cmd_warn "vgchange -an $vgname --devicesfile $vgname"
    svg_cmd_warn "vgchange --lockstop $vgname --devicesfile $vgname"
    # slow method
    # svg_cmd_warn "vgchange -an $vgname --devicesfile $vgname"
    # svg_cmd_warn "vgremove -ff $vgname --devicesfile $vgname"
    #    if [ $? -ne 0 ] ;then
    #     svg_cmd_warn "vgchange --lockstop --devicesfile $vgname"
    #    fi
  else
    kslog_warn "VG ${vgname} NOT found"
    return 1
  fi

  if [[ "$devs" != "" ]]; then
    kslog_info $devs
    for dev in ${devs}; do
      svg_cmd_warn "wipefs -a $dev"
      # optional
      svg_cmd_warn "lvmdevices --deldev $dev"
      svg_cmd_warn "lvmdevices --devicesfile $vgname --deldev $dev"
    done

    #svg_cmd_warn "yes|pvremove --devicesfile $vgname -ff --config global/use_lvmlockd=0 $dev"
    #svg_cmd_exit "lvmdevices --devicesfile $vgname --deldev $dev"
  fi
  rm -rf /etc/lvm/devices/${vgname}

}

svg_lv_remove() {

  local OPT OPTARG OPTIND
  local usage vgname lvname poolname
  usage="${FUNCNAME} <-v vgname> [-l lvname -p poolname]"

  while getopts 'v:l:p:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    l)
      lvname="$OPTARG"
      ;;
    p)
      poolname="$OPTARG"
      ;;
    ? | h)
      kslog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  lvname=${lvname:-${LV_NAME}}
  poolname=${poolname:-${POOL_NAME}}

  if [ -z "${vgname}" ] || [ -z "${lvname}" ] || [ -z "${poolname}" ]; then
    kslog_error "${usage}, Miss parameter !"
    return 1
  fi

  kslog_info "Ready delete ${lvname} and ${poolname} in ${vgname}"
  mylvs=$(lvs --devicesfile $vgname | awk '{print $1}' | grep -E ${lvname}-[0-9]*)
  for mylv in $mylvs; do
    #svg_cmd_exit "lvchange -an --devicesfile $vgname -f $vgname/$mylv"
    svg_cmd_warn "lvremove --devicesfile $vgname -f $vgname/$mylv"
  done
  mypools=$(lvs --devicesfile $vgname | awk '{print $1}' | grep -E ${poolname}-[0-9]*)
  for mypool in $mypools; do
    #svg_cmd_exit "lvchange -an --devicesfile $vgname -f $vgname/$mypool"
    svg_cmd_warn "lvremove --devicesfile $vgname -f $vgname/$mypool"
  done

}

_write_stg_file() {
  # write stage result into file
  # usage: time funcname
  #multi-node env dont care the vgname
  local file=${LOG_DIR}/$2_${TEST_NAME}.stg
  local curren_time last_time
  current_time=$(date +%s)
  if [ -e $file ]; then
    last_idx=$(tail -n 1 $file | cut -f 1 -d ":")
    if ((last_idx == $1)); then
      kslog_warn "Exist same idx, quit."
      return
    fi
    last_time=$(tail -n 1 $file | cut -f 2 -d ":")
    time=$((current_time - last_time))
    svg_cmd "echo $1 :${current_time} : ${time} |tee -a $file"
  else
    svg_cmd "echo $1 :${current_time} : 0|tee -a $file"
  fi
}

_write_time_file() {
  # usage: time funcname
  local file="${LOG_DIR}/$2_${vgname}_${WORKER}_${num}_${start}-$((start + num)).time"
  svg_cmd "echo $1 : $(date '+%m-%d %H:%M:%S') > $file"
}

_write_error_file() {
  # usage: wrong_cmd
  local file="${LOG_DIR}/$2_${TEST_NAME}.err"
  svg_cmd "echo $1  |tee -a $file"
}

_write_rotate_file() {
  #handle logfile and
  ENABLE_RORATE=1
  if [ -n "${ENABLE_RORATE}" ]; then
    kslog_rotate_log
  fi
}

_hande_stage() {
  if ((g_idx % unit_stage == 0)); then
    _write_stg_file $g_idx ${funcname}
    _write_rotate_file
  fi
}

_write_idx_file() {
  # usage: file lockfile
  local file=$1
  exec 200>$lockfile
  flock -x 200
  g_idx=$(cat ${file})
  svg_cmd "echo $((g_idx + 1)) > ${file};"
  flock -u 200
  exec 200>&-
}

svg_loop_test() {
  local OPT OPTARG OPTIND
  local usage vgname num start reset_count count_file opts
  local funcname action cmd
  usage="${FUNCNAME} <-f funcname> <-a action> <-v vgname> <-n num> [-s start] [-o opts]  [-c count_file] [-r reset_count] [-u unit_stage]"

  while getopts 'a:f:v:n:s:r:c:o:u:h' OPT; do
    case $OPT in
    f)
      funcname="$OPTARG"
      ;;
    a)
      action="$OPTARG"
      ;;
    v)
      vgname="$OPTARG"
      ;;
    n)
      num="$OPTARG"
      ;;
    s)
      start="$OPTARG"
      ;;
    r)
      reset_count="$OPTARG"
      ;;
    c)
      count_file="$OPTARG"
      ;;
    o)
      opts="$OPTARG"
      ;;
    u)
      unit_stage="$OPTARG"
      ;;
    h)
      kslog_error ${usage}
      return 1
      ;;
    \?) ;;
    esac
  done

  funcname=${funcname:-"undef"}
  action=${action:-}
  vgname=${vgname:-${VG_NAME}}
  num=${num:-$NUM_LV}
  start=${start:-0}
  reset_count=${reset_count:-0}
  count_file=${count_file:-${LOG_DIR}/${funcname}.idx}
  unit_stage=${unit_stage:-${UNIT_STAGE}}
  opts=${opts:-""}

  kslog_info "
  ${FUNCNAME}
  funcname=${funcname}
  action=${action}
  vgname=${vgname}
  num=${num}
  start=${start}
  reset_count=${reset_count}
  count_file=${count_file}
  unit_stage=${unit_stage}
  opts=${opts}
  "

  if [ -z "${vgname}" ] || [ -z "${num}" ] || [ -z "${count_file}" ]; then
    kslog_error "${usage}, Miss parameter !"
    return 1
  fi

  if [ "${reset_count}" == "1" ] || [ ! -e ${count_file} ]; then
    svg_cmd_exit "echo 0 > ${count_file}"
  fi

  local lockfile=${LOG_DIR}/$funcname_${TEST_NAME}.lock
  [ -e $lockfile ] || touch $lockfile

  kslog_info "Loop begin ${FUNCNAME} on ${WORKER} ${vgname} ${num} ${start}"
  start_time=$(date +%s)
  err_count=0
  for ((i = 0; i < num; i++)); do
    idx=$((start + i))
    # g_idx=$(cat ${count_file})
    # svg_cmd "echo $((g_idx + 1)) > ${count_file};"
    _write_idx_file ${count_file}
    cmd="$(eval echo $action)"
    svg_cmd_warn "${cmd}" "${funcname}"
    if [ $? != 0 ]; then
      ((err_count++))
      _write_error_file "$cmd"
    fi
    _hande_stage
  done
  end_time=$(date +%s)
  t=$((end_time - start_time))
  _write_time_file $t ${funcname}
  # refresh to check last
  g_idx=$(cat ${count_file})
  _hande_stage
  kslog_info "Loop end ${funcname} on ${WORKER} ${vgname} ${num} ${start} Time: $t Err:$err_count"
  return $((err_count == 0 ? 0 : 1))

}

svg_lv_create() {
  action='lvcreate -L ${SIZE_LV}M -V ${SIZE_POOL}M -n ${LV_NAME}-${idx} --thinpool ${POOL_NAME}-${idx} ${opts} --devicesfile ${vgname} ${vgname}'
  svg_loop_test -f lvcreate -a "$action" $@
}

svg_lv_change() {
  action='lvchange ${vgname}/${LV_NAME}-${idx} ${opts} --devicesfile ${vgname} '

  svg_loop_test -f lvchange -a "$action" $@
}

svg_lv_extend() {
  action="lvextend -L+10M  "'${vgname}/${POOL_NAME}-${idx} ${opts} --devicesfile ${vgname}'
  svg_loop_test -f lvextend -a "$action" $@
}
# svg_change_lv() {
#   local OPT OPTARG OPTIND
#   local usage vgname num start reset_count count_file opts
#   usage="${FUNCNAME} <-v vgname> <-n num> [-s start] [-o opts]  [-c count_file] [-r reset_count] [-u unit_stage]"

#   while getopts 'v:n:s:r:c:o:u:h' OPT; do
#     case $OPT in
#     v)
#       vgname="$OPTARG"
#       ;;
#     n)
#       num="$OPTARG"
#       ;;
#     s)
#       start="$OPTARG"
#       ;;
#     r)
#       reset_count="$OPTARG"
#       ;;
#     c)
#       count_file="$OPTARG"
#       ;;
#     o)
#       opts="$OPTARG"
#       ;;
#     u)
#       unit_stage="$OPTARG"
#       ;;
#     ? | h)
#       kslog_error ${usage}
#       return 1
#       ;;
#     esac
#   done

#   vgname=${vgname:-${VG_NAME}}
#   num=${num:-$NUM_LV}
#   start=${start:-0}
#   reset_count=${reset_count:-0}
#   count_file=${count_file:-${COUNT_FILE}}
#   unit_stage=${unit_stage:-${UNIT_STAGE}}
#   opts=${opts:-"-ay"}

#   if [ -z "${vgname}" ] || [ -z "${num}" ] || [ -z "${count_file}" ]; then
#     kslog_error "${usage}, Miss parameter !"
#     return 1
#   fi

#   if [ "${reset_count}" == "1" ]; then
#     svg_cmd_exit "echo 0 > ${count_file}"
#   fi

#   kslog_info "Loop begin ${FUNCNAME} on ${WORKER} ${vgname} ${num} ${start}"
#   start_time=$(date +%s)
#   err_count=0
#   for ((i = 0; i < num; i++)); do
#     idx=$((start + i))
#     g_idx=$(cat ${count_file})
#     svg_cmd "echo $((g_idx + 1)) > ${count_file};"
#     svg_cmd_warn "lvcreate -L ${SIZE_LV}M -V ${SIZE_POOL}M -n ${LV_NAME}-${idx} --thinpool ${POOL_NAME}-${idx} ${opts} --devicesfile ${vgname} ${vgname}"
#     [ $? == 0 ] || ((err_count++))
#     ((g_idx % unit_stage == 0)) && _write_stg_file $g_idx ${FUNCNAME}
#   done
#   end_time=$(date +%s)
#   t=$((end_time - start_time))
#   _write_time_file $t ${FUNCNAME}
#   _write_stg_file $g_idx ${FUNCNAME}
#   kslog_info "Loop end ${FUNCNAME} on ${WORKER} ${vgname} ${num} ${start} Time: $t Err:$err_count"

# }

svg_remove_all() {
  local OPT OPTARG OPTIND
  local usage vgname devs dev
  usage="${FUNCNAME} <-v vgname> "

  while getopts 'v:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    ? | h)
      kslog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}

  if [ -z "${vgname}" ]; then
    kslog_error "${usage}, Miss parameter !"
    return 1
  fi
  svg_lv_remove -v ${vgname}
  svg_vg_remove -v ${vgname}
}

svg_vg_reset() {
  local OPT OPTARG OPTIND
  local usage vgname devs dev
  usage="${FUNCNAME} <-v vgname> [-d devs]"

  while getopts 'v:d:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    d)
      devs="$OPTARG"
      ;;
    ? | h)
      kslog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}

  if [ -z "${vgname}" ]; then
    kslog_error "${usage}, Miss parameter !"
    return 1
  fi
  svg_vg_remove -v ${vgname}
  svg_vg_create -v ${vgname} -d "$devs"
}

svg_prune_vg() {
  #
  #systemctl restart lvm2-monitor.service
  lvdisplay -a $vgname
  rm -rf /etc/lvm/archive/$vgname*
  #  svg_cmd_exit "vgchange --archivepool-prune $vgname"

}
