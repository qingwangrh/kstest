#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DISABLE_COLOR='\033[0m' # Disable Color

#Default
REPEAT=1
NUM_LV=100
NUM_VG=0
NUM_LUN=0
UNIT_LV=16
INIT_FLAG=0
REMAIN_LUNSIZE=2048
METADATA_SIZE=128
ACTIVE=1

VG_NAME=ksvg
POOL_NAME=kspool
LV_NAME=kslv

NFS_FOLDER=/var/tmp
TEST_NAME=t1
WORKER="0"
VG_DEVS=()
LOG_FILE=/tmp/kstest.log
#[[ "$kubesan_test_log" == "" ]] && wlog_file=/tmp/wlog.out || wlog_file=$kubesan_test_log

function wlog_set_log() {
  # parameter: logfile reset
  LOG_FILE=$1
  # empty log
  [[ "$2" == "1" ]] && {
    echo "reset"
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
  local usage idx devs vgname metadatasize
  usage="${FUNCNAME} <vgname> <LUNS> [metadatasize]"
  if (($# < 2)); then
    wlog_error "${usage}"
    return 1
  fi

  vgname=$1
  devs=${2:-"${LUNS}"}
  metadatasize=${3:-${METADATA_SIZE}}
  echo "$devs"

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
  local usage dev vgname idx usage
  usage="${FUNCNAME} <vgname> "
  if (($# < 1)); then
    wlog_error "${usage}"
    return 1
  fi

  for ((idx = 0; idx < NUM_VG; idx++)); do
    vgname=${VG_NAME}${idx}
    devs=${VG_DEVS[$idx]}

    if vgs --devicesfile $vgname $vgname; then
      dev=$(
        pvs --devicesfile $vgname | awk -v vgname="$vgname" '{if ($2 == vgname) { print $1 }} '
      )
      echo $dev
      svg_cmd_warn "vgchange -an $vgname --devicesfile $vgname"
      svg_cmd_warn "vgremove -ff $vgname --devicesfile $vgname"
      #    if [ $? -ne 0 ] ;then
      #     svg_cmd_warn "vgchange --lockstop --devicesfile $vgname"
      #    fi
    fi

    if [[ "$dev" != "" ]]; then
      :
      svg_cmd_warn "lvmdevices --deldev $dev"

      #svg_cmd_warn "yes|pvremove --devicesfile $vgname -ff --config global/use_lvmlockd=0 $dev"
      #svg_cmd_exit "lvmdevices --devicesfile $vgname --deldev $dev"
    fi

  done

}

svg_calc() {
  ((poolsize = lunsize - remain_lunsize))
  ((num = poolsize / lvunit))
  echo $num $lvnum
  [[ "$lvnum" == "" ]] || ((num = num > lvnum ? lvnum : num))
  echo "poolsize=$poolsize lvunit=$lvunit num=$num"

}

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
  local start_time end_time func usage start num
  usage="$FUNCNAME FUNC NUMBER START"

  start_time=$(date +%s)
  func=$1
  num=${2:-${NUM_LV}}
  start=${3:-0}
  for ((i = start; i < num + start; i++)); do
    echo "$i $func"
    g_idx=$(cat ${COUNT_FILE})
    svg_cmd_exit "$func $g_idx $i" "$func"
    let g_idx+=1
    svg_cmd "echo $g_idx > ${COUNT_FILE};"
  done
  end_time=$(date +%s)
  wlog_info "Loop Test $func $num from $start Time: $((end_time - start_time))"

}

svg_create_lv() {
  local vgname lvname poolname
  lvtest_vg_idx=${lvtest_vg_idx:-0}
  vgname=${VG_NAME}${lvtest_vg_idx}
  lvname="${LV_NAME}-g$1-l$2"
  poolname="${POOL_NAME}-g$1-l$2"
  echo "${vgname} ${lvname} ${poolname}"
  #  lvcreate --devicesfile ${vgname} --type thin -V 2G -n ${lvname}  --thinpool ${poolname} ${vgname}
  svg_cmd_warn "lvcreate -L ${UNIT_LV}M -V ${UNIT_LV}M -n ${lvname} --thinpool ${poolname} -an --devicesfile ${vgname} ${vgname}" "lvcreate"
  #lvcreate -L ${UNIT_LV}M -V ${UNIT_LV}M -n ${lvname} --thinpool ${poolname} -an --devicesfile ${vgname} ${vgname}
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
svg_test_lv() {
  num=${1:-$NUM_LV}
  start=${2:0}
  #  locate loop_num
  #  ROUND_NUM=${ROUND_NUM:-50}
  #  echo $NUM_LV
  #  r=$((NUM_LV/ROUND_NUM))
  #  for ((r=0;i<=$((NUM_LV/ROUND_NUM));r++));do
  #    svg_loop_test svg_create_lv $ROUND_NUM $((r*ROUND_NUM))
  #  done
  svg_loop_test svg_create_lv $num $start

}
#svg_test_lv_extend() {
#  :
#}

svg_del_lv() {
  local vgname lvname poolname
  for ((idx = 0; idx < NUM_VG; idx++)); do
    vgname=${VG_NAME}${idx}
    #  vgname=$1
    wlog_info "Ready delete ${LV_NAME} and ${POOL_NAME}"
    mylvs=$(lvs --devicesfile $vgname | awk '{print $1}' | grep -E ${LV_NAME}-[0-9]*)
    for mylv in $mylvs; do
      #svg_cmd_exit "lvchange -an --devicesfile $vgname -f $vgname/$mylv"
      svg_cmd_warn "lvremove --devicesfile $vgname -f $vgname/$mylv"
    done
    mypools=$(lvs --devicesfile $vgname | awk '{print $1}' | grep -E ${POOL_NAME}-[0-9]*)
    for mypool in $mypools; do
      #svg_cmd_exit "lvchange -an --devicesfile $vgname -f $vgname/$mypool"
      svg_cmd_warn "lvremove --devicesfile $vgname -f $vgname/$mypool"
    done
  done

}

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
