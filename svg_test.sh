#!/bin/bash
#set -x
source svg_common.sh

usage="$0 <-t testname> <-v vgname> <-d devname> <-w worker> <-s nfs> [-i] [-u lvunit ] [-r loop ]
[-n lvnum ] [-m metasize] [-a 1/0 active]  [-l logfile] [-e function]\n

-t testname: The test name, log file and count file can be generated with this.
-v vgname  : The VG name for testing.
-d devname : The LNU devices name.
-s nfs : The local nfs folder, it is used to store test result.
-w worker  : The worker node name. it helps to distinguish host resource
-u lvunit : The size (Megabyte) of a LV or pool.
            optional. default is 16.
-r loop   : The loop test number. optional. default is 1.
-n lvnum  : The number of LV/pool. optional. default is auto calc.
            If specify it, the final value is min(lvnum, auto).
-m metasize : The meta size of VG, default  128M.
-a active   : Active flag of LV. 1:active(default) 0 deactive.

-l logfile  : The path of logfile. can be generated automately.\n
Example : $0 -t mytest -v myvg -d /dev/sdb -c 1000 -e svg_test_lv p hostx -u 1024 -r 1 -n 2 \n
          # First server
          $0 -d /dev/sdb -p hosta -l /home/vwrepo/tmp/x.log -i
          # Second server
          $0 -d /dev/sdb -p hostb -l /home/vwrepo/tmp/x.log
          $0 -d /dev/sdb -p hostc -e svg_del_lv \n"

#Default
LUNS=/dev/sdb

REPEAT=1
NUM_LV=5
NUM_VG=1
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
NFS_FOLDER=/home/vwrepo

WORKER="h"$(cat /etc/lvm/lvmlocal.conf | grep -E "host_id.*=.*[0-9]" | cut -f 2 -d "=" | bc -l)

while getopts "ihdt::u:r:n:m:c:a:v:l:p:e:w:" opt; do
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
  u)
    UNIT_LV=$OPTARG
    ;;
  e)
    FUNCRUN="$OPTARG"
    ;;
  s)
    NFS_FOLDER="$OPTARG"
    ;;
  r)
    REPEAT="$OPTARG"
    ;;
  m)
    echo "$OPTARG"
    METADATA_SIZE=$OPTARG
    ;;
  a)
    echo "$OPTARG"
    ACTIVE=$OPTARG
    ;;
  l)
    echo "$OPTARG"
    LOG_FILE=$OPTARG
    ;;
  ? | *)
    echo -e "$usage"
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done

TEST_NAME=${TEST_NAME:-${VG_NAME}}
#Parameter priority : input > test name script > default
# Load Test Name Parameter
if [ -e ${TEST_NAME}.sh ]; then
  source ${TEST_NAME}.sh
fi


# Revise value
UNIT_POOL=${UNIT_POOL:-${UNIT_LV}}

LOG_FOLDER=${LOG_FOLDER:-${NFS_FOLDER}/kslog/${TEST_NAME}}

[[ -e ${LOG_FOLDER} ]] || mkdir -p ${LOG_FOLDER}

LV_NAME="${LV_NAME}-${WORKER}"
POOL_NAME="${POOL_NAME}-${WORKER}"

for dev in ${LUNS}; do
  let NUM_LUN+=1
done

# if ((NUM_VG>NUM_LUN || NUM_VG==0));then
#   NUM_VG=${NUM_LUN}
# fi

if [ -z "${LOG_FILE}" ]; then
  # LOG_FILE="${LOG_FOLDER}/kubesan-"$(date "+%F-%H%M").log
  LOG_FILE="${LOG_FOLDER}/ks.${TEST_NAME}.log"
fi
if [ -z "${COUNT_FILE}" ]; then
  COUNT_FILE="${LOG_FOLDER}/ks.${TEST_NAME}.ct"
fi

[[ -e ${COUNT_FILE} ]] || { touch ${COUNT_FILE};INIT_FLAG=1; }
[[ "${INIT_FLAG}" == "1" ]] && { echo 0 >${COUNT_FILE}; }

# wlog_set_log ${LOG_FILE} 

if [ ! -e ${LOG_FILE} ];then
touch ${LOG_FILE}
wlog_info "Hello, ${LOG_FILE}"

wlog_info "
LUNS=${LUNS}
NUM_LV=${NUM_LV}
NUM_VG=${NUM_VG}
NUM_LUN=${NUM_LUN}
UNIT_LV=${UNIT_LV}
UNIT_POOL=${UNIT_POOL}
LV_NAME=${LV_NAME}
VG_NAME=${VG_NAME}
POOL_NAME=${POOL_NAME}
METADATA_SIZE=${METADATA_SIZE}
NFS_FOLDER=${NFS_FOLDER}
INIT_FLAG=${INIT_FLAG}
TEST_NAME=${TEST_NAME}
LOG_FILE=${LOG_FILE}
COUNT_FILE=${COUNT_FILE}
"
fi

if [[ "${FUNCRUN}" != "" ]]; then
  wlog_info "Run ${FUNCRUN}"
  # set -v
  eval ${FUNCRUN}
  wlog_info "Please check result in $LOG_FILE"
  # set +v
# else

#   #  svg_create_vg "${LUNS}" ${METADATA_SIZE}
#   #  svg_test_lv_multi_pool $active
#   #  svg_del_all
#   svg_test_lv_multi_pool
fi