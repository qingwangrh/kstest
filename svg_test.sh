#!/bin/bash
#set -x

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

usage="$0 <-t testname> <-v vgname> <-d devname> [-r log rootdir] 
[-w worker] [-n lvnum ] [-u stage unit]
[-i] [-s lvsize ]    [-e function]\n

-t testname: The test name, log file and count file can be generated with this.
-v vgname  : The VG name for testing.
-d devname : The LNU devices name.
-r logrootdir: The root path of log files. if no logdir defined, this vaule
               may help to build logdir.
========================
-l logdir : The path of log files. It can be build by log rootdir 
            if it is not specified. 
-w worker  : The worker node name. It helps to distinguish host resource
-s lvsize : The size (Megabyte) of a LV or pool.
            optional. default is 16.
-n lvnum  : The number of LV/pool. optional. default is auto calc.
            If specify it, the final value is min(lvnum, auto).
-u stage unit : When the operation reaches a certain 
                number of times(stage), the log is rotated 
                and the duration is counted. default is 1000
-i : Re-init content of log file and count file. default 0

Example : 
 $0 -t lvcreate -e \"svg_lv_create  -v ksvg1 -n 2000 -s 0 -o '-an' -u 1000\"
 $0 -t lvchange -e \"svg_lv_change  -v ksvg1 -n 2000 -s 0 -o '-ay' -u 1000\"
 $0 -t lvextend -e \"svg_lv_extend  -v ksvg1 -n 2000 -s 0  -u 1000\"
          
          "

#Default
LUNS=/dev/sdb
NUM_LV=5
NUM_VG=1
NUM_LUN=0
SIZE_LV=16
UNIT_STAGE=1000
INIT_FLAG=0
REMAIN_LUNSIZE=2048
METADATA_SIZE=128
ACTIVE=1
VG_NAME=ksvg1
POOL_NAME=kspool
LV_NAME=kslv

LOG_ROOTDIR=/var/tmp
LOG_ROOTDIR=/home/vwrepo/kslog

WORKER="h"$(cat /etc/lvm/lvmlocal.conf | grep -E "host_id.*=.*[0-9]" | cut -f 2 -d "=" | bc -l)

while getopts "ihd:t::u:r:n:m:c:a:v:l:p:e:w:" opt; do
  case $opt in
  h)
    echo -e "$usage"
    exit 0
    ;;
  t)
    TEST_NAME="$OPTARG"
    ;;
  i)
    INIT_FLAG=1
    ;;
  d)
    LUNS="$OPTARG"
    ;;
  n)
    NUM_LV="$OPTARG"
    ;;
  v)
    VG_NAME="$OPTARG"
    ;;
  w)
    WORKER="$OPTARG"
    ;;
  s)
    SIZE_LV=$OPTARG
    ;;
  e)
    FUNCRUN="$OPTARG"
    ;;
  r)
    LOG_ROOTDIR="$OPTARG"
    ;;
  l)
    LOG_DIR=$OPTARG
    ;;
  u)
    UNIT_STAGE=$OPTARG
    ;;
  ? | *)
    echo -e "$usage"
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done

# Revise value
TEST_NAME=${TEST_NAME:-${VG_NAME}}

#Parameter priority : test name script>input > default
# Load Test Name Parameter
if [ -e ${TEST_NAME}.sh ] && [ "${ENABLE_SCRIPT}" == "1" ]; then
  # Please take care to aviod nest source
  echo "Load script file ${WORK_PATH}/${TEST_NAME}.sh"
  source ${WORK_PATH}/${TEST_NAME}.sh
fi

SIZE_POOL=${SIZE_POOL:-${SIZE_LV}}

if [ -n "$LOG_ROOTDIR" ]; then
  LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
fi

if [ -z "${TEST_NAME}" ] || [ -z "${LOG_DIR}" ]; then
  echo -e "$usage"
  exit 1
fi

[[ -e ${LOG_DIR} ]] || mkdir -p ${LOG_DIR}

LV_NAME="${LV_NAME}-${WORKER}"
POOL_NAME="${POOL_NAME}-${WORKER}"

for dev in ${LUNS}; do
  let NUM_LUN+=1
done

# if ((NUM_VG>NUM_LUN || NUM_VG==0));then
#   NUM_VG=${NUM_LUN}
# fi

LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}

COUNT_FILE=${COUNT_FILE:-"${LOG_DIR}/main.idx"}

[[ -e ${COUNT_FILE} ]] || {
  touch ${COUNT_FILE}

}

if [[ "${INIT_FLAG}" == "1" ]]; then
  echo 0 >${COUNT_FILE}
  kslog_rotate_log
fi

if [ ! -e ${LOG_FILE} ] || [[ "$(head -n 1 ${LOG_FILE})" == "" ]]; then
  touch ${LOG_FILE}
  kslog_info "Hello, ${TEST_NAME} ${LOG_FILE}"
  svg_version
  kslog_info "
 ================================ 
TEST_NAME=${TEST_NAME}
LUNS=${LUNS}
NUM_LV=${NUM_LV}
NUM_VG=${NUM_VG}
NUM_LUN=${NUM_LUN}
SIZE_LV=${SIZE_LV}
SIZE_POOL=${SIZE_POOL}
LV_NAME=${LV_NAME}
VG_NAME=${VG_NAME}
POOL_NAME=${POOL_NAME}
METADATA_SIZE=${METADATA_SIZE}
INIT_FLAG=${INIT_FLAG}

LOG_ROOTDIR=${LOG_ROOTDIR}
LOG_DIR=${LOG_DIR}
LOG_FILE=${LOG_FILE}
COUNT_FILE=${COUNT_FILE}
UNIT_STAGE=${UNIT_STAGE}
"
fi

if [[ "${FUNCRUN}" != "" ]]; then
  kslog_info "Run ${FUNCRUN}"
  # set -v
  eval ${FUNCRUN}
  kslog_info "Please check result in $LOG_FILE"

fi
