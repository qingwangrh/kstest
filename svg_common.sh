#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DISABLE_COLOR='\033[0m' # Disable Color

function wlog_set_log() {
  # parameter: logfile reset
  LOG_FILE=$1
  # empty log
  [[ "$2" == "1" ]] && {
    echo "Reset ${LOG_FILE}"
    echo "" >${LOG_FILE}
  }

}

function wlog_color() {
  printf "$1"
  shift
  printf "$(date '+%m-%d %H:%M:%S') | $*\n" | tee -a ${LOG_FILE}
  printf "${DISABLE_COLOR}"
}

function wlog_error {
  wlog_color "${RED}" "$@"
}

function wlog_info {
  wlog_color "${GREEN}" "$@"
}

function wlog_warn {
  wlog_color "${YELLOW}" "$@"
}

function _exit_on_error() {
  owner=$0
  ret=$1
  msg=$2
  # set -xv
  if [ $1 -ne 0 ]; then
    shift
    wlog_error "$@"
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
    wlog_warn "$@"
  fi
}

svg_version() {
  wlog_info "$({
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
   systemctl restart wdmdsanlock lvmlockd

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
  wlog_info "CMD: $1"
  eval "$1"
  ret=$?
  end_time=$(date +%s)
  wlog_info "Time $2: $((end_time - start_time)) "
  return $ret
}

svg_cmd() {
  wlog_info "CMD: $@"
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
  #   wlog_error "Error($ret) on $@"
  #   exit $ret
  # fi
}

svg_cmd_warn() {
  svg_cmd_time "$@"
  ret=$?
  if [ $ret -ne 0 ]; then
    wlog_warn "Error($ret) on $@"
  fi
  return $ret
}

svg_create_vg() {
  local OPT OPTARG OPTIND
  local usage vgname devs metadatasize
  usage="${FUNCNAME} <-v vgname> <-d LUNS> [-m metadatasize]"

  while getopts 'v:d:m:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    d)
      luns="$OPTARG"
      ;;
    m)
      metadatasize="$OPTARG"
      ;;
    ? | h)
      wlog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  devs=${devs:-"${LUNS}"}
  metadatasize=${metadatasize:-${METADATA_SIZE}}

  if [ -z "${vgname}" ] || [ -z "${devs}" ]; then
    wlog_error "${usage}, Miss parameter !"
    return 1
  fi

  if vgs --devicesfile $vgname $vgname; then
    wlog_warn "Already exist $vgname,skip creating $vgname"
    return
  fi
  for dev in ${devs}; do
    svg_cmd_exit "lvmdevices --devicesfile $vgname --adddev $dev"
  done

  svg_cmd_exit "vgcreate --shared $vgname ${devs} --config global/sanlock_align_size=2 --metadatasize ${metadatasize}"

  svg_cmd_exit "vgchange --devicesfile $vgname --lock-start"
  svg_cmd_exit "vgs --devicesfile $vgname $vgname"
  svg_cmd_exit "vgdisplay --devicesfile $vgname -C -o name,mda_size,mda_free $vgname"

  # idx=0

  # for dev in ${devs}; do
  #   echo $dev
  #   vg_idx=$((idx % NUM_VG))
  #   vgname=${VG_NAME}${vg_idx}
  #   let idx+=1
  #   VG_DEVS[$vg_idx]="${VG_DEVS[$vg_idx]} $dev"

  #   #    lunsize=$(lsblk -nd $dev -b | awk '{print $4}')
  #   #    ((lunsize = lunsize / 1024 / 1024)) # Unit M
  #   #
  #   #    echo "Lun lunsize:$lunsize"
  #   #    #svg_cmd_exit "pvcreate --config global/use_lvmlockd=0 --metadatasize 64m  $devs"
  #   svg_cmd_exit "lvmdevices --devicesfile $vgname --adddev $dev"
  # done

  # for ((idx = 0; idx < NUM_VG; idx++)); do
  #   vgname=${VG_NAME}${idx}
  #   devs=${VG_DEVS[$idx]}
  #   if vgs --devicesfile $vgname $vgname; then
  #     wlog_warn "Already exist $vgname,skip creating $vgname"
  #   else
  #     svg_cmd_exit "vgcreate --shared $vgname ${devs} --config global/sanlock_align_size=2 --metadatasize ${metadatasize}"
  #   fi
  #   svg_cmd_exit "vgchange --devicesfile $vgname --lock-start"
  #   svg_cmd_exit "vgs --devicesfile $vgname $vgname"
  #   svg_cmd_exit "vgdisplay --devicesfile $vgname -C -o name,mda_size,mda_free $vgname"
  # done

}

svg_del_vg() {
  local OPT OPTARG OPTIND
  local usage dev vgname idx usage
  usage="${FUNCNAME} <-v vgname> "

  while getopts 'v:h' OPT; do
    case $OPT in
    v)
      vgname="$OPTARG"
      ;;
    ? | h)
      wlog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}

  if [ -z "${vgname}" ]; then
    wlog_error "${usage}, Miss parameter !"
    return 1
  fi

  if svg_cmd "vgs --devicesfile $vgname $vgname"; then
    devs=$(
      pvs --devicesfile $vgname | awk -v vgname="$vgname" '{if ($2 == vgname) { print $1 }} '
    )

    svg_cmd_warn "vgchange -an $vgname --devicesfile $vgname"
    svg_cmd_warn "vgremove -ff $vgname --devicesfile $vgname"
    #    if [ $? -ne 0 ] ;then
    #     svg_cmd_warn "vgchange --lockstop --devicesfile $vgname"
    #    fi
  else
    wlog_warn "VG ${vgname} NOT found"
    return 1
  fi

  if [[ "$devs" != "" ]]; then
    wlog_info $devs
    for dev in ${devs}; do
      svg_cmd_warn "lvmdevices --deldev $dev"
      svg_cmd_warn "lvmdevices --devicesfile $vgname --deldev $dev"
    done

    #svg_cmd_warn "yes|pvremove --devicesfile $vgname -ff --config global/use_lvmlockd=0 $dev"
    #svg_cmd_exit "lvmdevices --devicesfile $vgname --deldev $dev"
  fi
  rm -rf /etc/lvm/devices/${vgname}

  #========================
  # for ((idx = 0; idx < NUM_VG; idx++)); do
  #   vgname=${VG_NAME}${idx}
  #   devs=${VG_DEVS[$idx]}

  #   if vgs --devicesfile $vgname $vgname; then
  #     dev=$(
  #       pvs --devicesfile $vgname | awk -v vgname="$vgname" '{if ($2 == vgname) { print $1 }} '
  #     )
  #     echo $dev
  #     svg_cmd_warn "vgchange -an $vgname --devicesfile $vgname"
  #     svg_cmd_warn "vgremove -ff $vgname --devicesfile $vgname"
  #     #    if [ $? -ne 0 ] ;then
  #     #     svg_cmd_warn "vgchange --lockstop --devicesfile $vgname"
  #     #    fi
  #   fi

  #   if [[ "$dev" != "" ]]; then
  #     :
  #     svg_cmd_warn "lvmdevices --deldev $dev"

  #     #svg_cmd_warn "yes|pvremove --devicesfile $vgname -ff --config global/use_lvmlockd=0 $dev"
  #     #svg_cmd_exit "lvmdevices --devicesfile $vgname --deldev $dev"
  #   fi

  # done

}

# svg_calc() {
#   ((poolsize = lunsize - remain_lunsize))
#   ((num = poolsize / lvunit))
#   echo $num $lvnum
#   [[ "$lvnum" == "" ]] || ((num = num > lvnum ? lvnum : num))
#   echo "poolsize=$poolsize lvunit=$lvunit num=$num"

# }

#svg_test_lv_one_pool() {
#  local active
#  svg_calc
#  svg_cmd_exit "lvcreate --devicesfile $vgname --type thin-pool -L ${poolsize}M -n $lvpoolname $vgname "
#  [[ "$1" == "" ]] && active=1 || active=$1
#
#  for r in $(seq $repeat); do
#    for i in $(seq $num); do
#      iter_lvname="${lvname}$i"
#      echo "repeat:$r $i/$num ${iter_lvname}"
#      svg_cmd_exit "lvcreate --devicesfile $vgname --type thin -V ${lvunit}M -n ${iter_lvname} --thinpool $lvpoolname $vgname"
#      if [[ "$active" == "1" ]];then
#        svg_cmd_exit "mkfs.ext4 /dev/${vgname}/${iter_lvname} > /dev/null"
#      else
#        #deactive
#        svg_cmd_exit "lvchange --devicesfile $vgname --activate n /dev/${vgname}/${iter_lvname}"
#      fi
#    done
#    svg_del_lv
#  done
#
#}

svg_loop_test() {
  local OPT OPTARG OPTIND
  local usage start_time end_time func start num reset_global
  usage="$FUNCNAME <-e FUNC> <-n NUMBER> [-s START] [-r reset_global] [ -f count file]"

  while getopts 'e:n:s:r:f:h' OPT; do
    case $OPT in
    e)
      func="$OPTARG"
      echo "wq:$func"
      ;;
    n)
      num="$OPTARG"
      ;;
    s)
      start="$OPTARG"
      ;;
    r)
      reset_global="$OPTARG"
      ;;
    f)
      count_file="$OPTARG"
      ;;
    ? | h)
      wlog_error ${usage}
      return 1
      ;;
    esac
  done

  count_file=${count_file:-${COUNT_FILE}}
  num=${num:-${NUM_LV}}
  start=${start:-0}
  reset_global=${reset_global:-0}

  if [ -z "${func}" ] || [ -z "${num}" ]; then
    wlog_error "${usage}, Miss parameter !"
    return 1
  fi
  # Need reset count file
  if [[ "$reset_global" == "1" ]] && [ -n "${count_file}" ]; then
    svg_cmd "echo 0 > ${count_file}"
  fi
  g_idx=0
  start_time=$(date +%s)
  for ((i = start; i < num + start; i++)); do
    # echo "$i $func"
    if [ -n "${count_file}" ]; then
      g_idx=$(cat ${count_file})
      # svg_cmd "echo $((g_idx + 1)) > ${count_file};"
      echo $((g_idx + 1)) > ${count_file};
    fi
    # svg_cmd_exit "$func -g $g_idx -i $i"
    eval "$func -g $g_idx -i $i"
  done
  end_time=$(date +%s)
  wlog_info "Loop Test $func $num from $start Time: $((end_time - start_time))"

}

svg_create_lv() {
  # native function, should call
  local OPT OPTARG OPTIND
  local usage vgname lvname poolname g_idx l_idx
  usage="${FUNCNAME} <-v vgname> <-g global_idx> [-i local_idx]"

  while getopts 'v:l:p:g:i:h' OPT; do
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
    g)
      g_idx="$OPTARG"
      ;;
    i)
      i_idx="$OPTARG"
      ;;
    ? | h)
      echo "wq:er"
      wlog_error ${usage}
      # return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  lvname=${lvname:-${LV_NAME}}"-${g_idx}"
  poolname=${poolname:-${POOL_NAME}}"-${g_idx}"


  echo "${vgname} ${lvname} ${poolname}"
  #  lvcreate --devicesfile ${vgname} --type thin -V 2G -n ${lvname}  --thinpool ${poolname} ${vgname}
  svg_cmd_warn "lvcreate -L ${UNIT_LV}M -V ${UNIT_POOL}M -n ${lvname} --thinpool ${poolname} -an --devicesfile ${vgname} ${vgname}" "${FUNCNAME} ${lvname}"
  #lvcreate -L ${UNIT_LV}M -V ${UNIT_LV}M -n ${lvname} --thinpool ${poolname} -an --devicesfile ${vgname} ${vgname}
}

svg_del_lvs() {

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
      wlog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  lvname=${lvname:-${LV_NAME}}
  poolname=${poolname:-${POOL_NAME}}

  if [ -z "${vgname}" ] || [ -z "${lvname}" ] || [ -z "${poolname}" ]; then
    wlog_error "${usage}, Miss parameter !"
    return 1
  fi

  #  vgname=$1
  wlog_info "Ready delete ${lvname} and ${poolname} in ${vgname}"
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

#svg_test_lv_multi_pool() {
#  local active
##  svg_calc
#  [[ "$1" == "" ]] && active=${ACTIVE} || active=$1
#  for r in $(seq ${REPEAT}); do
#    for i in $(seq ${NUM_LV}); do
#      iter_lvname="${lvname}-$i"
#      iter_lvpoolname="${lvpoolname}-$i"
#      echo "repeat:$r $i/$num $iter_lvpoolname ${iter_lvname}"
#      svg_cmd_exit "lvcreate --devicesfile $vgname --type thin-pool -L ${lvunit}M -n $iter_lvpoolname $vgname "
#      svg_cmd_exit "lvcreate --devicesfile $vgname --type thin -V ${lvunit}M -n ${iter_lvname} --thinpool ${iter_lvpoolname} $vgname"
#      #active
#      if [[ "$active" == "1" ]];then
#        svg_cmd_exit "mkfs.ext4 /dev/${vgname}/${iter_lvname} > /dev/null"
#      else
#        #deactive
#        svg_cmd_exit "lvchange -an /dev/${vgname}/${iter_lvname} --devicesfile $vgname"
#        svg_cmd_exit "lvchange -an /dev/${vgname}/${iter_lvpoolname} --devicesfile $vgname"
#      fi
#      if [[ "${nfs_file}" != "" ]];then
#        let g_idx=`cat ${nfs_file}`+1;
#        wlog_info "Global idx $g_idx"
#        svg_cmd "echo $g_idx > ${nfs_file};"
#      fi
#      sleep 1
#    done
#    svg_del_lv
#  done
#
#}
svg_test_lv_new(){
  local OPT OPTARG OPTIND
  local usage vgname num start reset_global cycle
  usage="${FUNCNAME} <-v vgname> <-n num> [-s start] [-r reset_global] [-c cycle]"

  while getopts 'v:n:s:r:c:h' OPT; do
    case $OPT in
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
      reset_global="$OPTARG"
      ;;
    c)
      cycle="$OPTARG"
      ;;
    ? | h)
      wlog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  num=${num:-$NUM_LV}
  start=${start:-0}
  reset_global=${reset_global:-0}
  cycle=${cycle:-1}

  if [ -z "${vgname}" ] || [ -z "${num}" ]; then
    wlog_error "${usage}, Miss parameter !"
    return 1
  fi
  unit_cycle=$((num/cycle))
  count_file=${count_file:-${COUNT_FILE}}
  #split to smaller loop number
  wlog_info "Loop begin ${FUNCNAME} on ${WORKER} ${vgname} ${num} ${start}"
  start_time=$(date +%s)
  err_count=0
  for ((i=0;i<num;i++));do
  idx=$((start+i))
  g_idx=$(cat ${count_file})
  svg_cmd "echo $((g_idx + 1)) > ${count_file};"
  # svg_create_lv -v $vgname -g $idx
  svg_cmd_warn "lvcreate -L ${UNIT_LV}M -V ${UNIT_POOL}M -n ${LV_NAME}-${idx} --thinpool ${POOL_NAME}-${idx} -an --devicesfile ${vgname} ${vgname}"
  [ $? == 0 ] || $((err_count++))
  # lvcreate -L ${UNIT_LV}M -V ${UNIT_POOL}M -n ${LV_NAME}-${idx} --thinpool ${POOL_NAME}-${idx} -an --devicesfile ${vgname} ${vgname}
  done
  end_time=$(date +%s)
  t=$((end_time - start_time))
  echo $t > ${LOG_FOLDER}/${FUNCNAME}.$vgname.${WORKER}.${num}.${start}-$((start=num)).t
  wlog_info "Loop end ${FUNCNAME} on ${WORKER} ${vgname} ${num} ${start} Time: $t Err:$err_count"
  # svg_loop_test "svg_create_lv ${vgname}" ${num} ${start} ${reset_global}

}

svg_test_lv() {
  local OPT OPTARG OPTIND
  local usage vgname num start reset_global
  usage="${FUNCNAME} <-v vgname> <-n num> [-s start] [-r reset_global] [-u unit_cycle]"

  while getopts 'v:n:s:r:u:h' OPT; do
    case $OPT in
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
      reset_global="$OPTARG"
      ;;
    u)
      unit_cycle="$OPTARG"
      ;;
    ? | h)
      wlog_error ${usage}
      return 1
      ;;
    esac
  done

  vgname=${vgname:-${VG_NAME}}
  num=${num:-$NUM_LV}
  start=${start:0}
  reset_global=${reset_global:-0}
  unit_cycle=${unit_cycle:-10000}

  if [ -z "${vgname}" ] || [ -z "${num}" ]; then
    wlog_error "${usage}, Miss parameter !"
    return 1
  fi

  #split to smaller loop number

  for ((r = 0; r <= $((num / unit_cycle)); r++)); do
    local remain=$((num - r * unit_cycle))
    remain=$((reset > unit_cycle ? unit_cycle : remain))
    svg_loop_test -e "svg_create_lv -v ${vgname}" -n ${remain} -s $((r * unit_cycle)) -r ${reset_global}
  done
  # svg_loop_test "svg_create_lv ${vgname}" ${num} ${start} ${reset_global}

}


#svg_test_lv_extend() {
#  :
#}

svg_del_all() {
  svg_del_lv
  svg_del_vg
}

svg_prune_vg() {
  #
  #systemctl restart lvm2-monitor.service
  lvdisplay -a $vgname
  rm -rf /etc/lvm/archive/$vgname*
  #  svg_cmd_exit "vgchange --archivepool-prune $vgname"

}
