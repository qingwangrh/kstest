#!/bin/bash
#set -x
source svg_common.sh

usage="$0 <-d devname> <-w worker> <-n nfs> [-i] [-u lvunit ] [-r loop ]
[-c lvnum ] [-m metasize] [-a 1/0 active] [-v vgnuma] [-l logfile] [-e function]\n

-d devname : The LNU devices name.
-w worker  : The worker node name. it helps to distinguish host resource
-n nfs : The local nfs folder, it is used to store global value.
-u lvunit : The size (Megabyte) of a LV or pool.
            optional. default is 16.
-r loop   : The loop test number. optional. default is 1.
-c lvnum  : The number of LV/pool. optional. default is auto calc.
            If specify it, the final value is min(lvnum, auto).
-m metasize : The meta size of VG, default  256M.
-a active   : Active flag of LV. 1:active(default) 0 deactive.

-l logfile  : The path of logfile.\n
Example : $0 -d /dev/sdb -p hostx -u 1024 -r 1 -n 2 \n
          # First server
          $0 -d /dev/sdb -p hosta -l /home/vwrepo/tmp/x.log -i
          # Second server
          $0 -d /dev/sdb -p hostb -l /home/vwrepo/tmp/x.log
          $0 -d /dev/sdb -p hostc -e svg_del_lv \n"

#Default
LUNS=/dev/sdb

REPEAT=1
NUM_LV=5
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

WORKER="h"`cat /etc/lvm/lvmlocal.conf|grep -E "host_id.*=.*[0-9]"|cut -f 2 -d "="|bc -l`

while getopts "ihd:u:r:n:m:c:a:v:l:p:e:" opt; do
  case $opt in
  h)
    echo -e "$usage"
    exit 0
    ;;
  i)
    INIT_FLAG=1
    ;;
  d)
    LUNS="$OPTARG"
    ;;
  c)
    NUM_LV="$OPTARG"
    ;;
  v)
    NUM_VG="$OPTARG"
    ;;
  p)
    WORKER="$OPTARG"
    ;;
  u)
    UNIT_LV=$OPTARG
    ;;
  e)
    FUNCRUN="$OPTARG"
    ;;
  n)
    NFS_FOLDER="$OPTARG"
    ;;
  r)
    REPEAT="$OPTARG"
    ;;
  c)
    echo "$OPTARG"
    NUM_LV=$OPTARG
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
  ?|*)
    echo -e "$usage"
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done

# Revise value

LOG_FOLDER=${NFS_FOLDER}/kslogs
LOG_FILE="${LOG_FOLDER}/kubesan-"$(date "+%F-%H%M").log
LOG_FILE="${LOG_FOLDER}/ks.log"
COUNT_FILE="${LOG_FOLDER}/ks.count"

[[ -e ${LOG_FOLDER} ]] || mkdir -p ${LOG_FOLDER}

LV_NAME="${LV_NAME}-${WORKER}"
POOL_NAME="${POOL_NAME}-${WORKER}"

echo ${INIT_FLAG}
[[ -e ${COUNT_FILE} ]] || INIT_FLAG=1
[[ "${INIT_FLAG}" == "1" ]] && { echo 0 > ${COUNT_FILE}; }
echo ${INIT_FLAG}
for dev in ${LUNS};do
    let NUM_LUN+=1
done

if ((NUM_VG>NUM_LUN || NUM_VG==0));then
  NUM_VG=${NUM_LUN}
fi
echo ${INIT_FLAG}
wlog_set_log ${LOG_FILE} ${INIT_FLAG}
wlog_info "Hello, ${LOG_FILE}"

wlog_info "
LUNS=${LUNS}
NUM_LV=${NUM_LV}
NUM_VG=${NUM_VG}
NUM_LUN=${NUM_LUN}
UNIT_LV=${UNIT_LV}
LV_NAME=${LV_NAME}
VG_NAME=${VG_NAME}
POOL_NAME=${POOL_NAME}
METADATA_SIZE=${METADATA_SIZE}
NFS_FOLDER=${NFS_FOLDER}
INIT_FLAG=${INIT_FLAG}
TEST_SCRIPT=${TEST_SCRIPT}
LOG_FILE=${LOG_FILE}
COUNT_FILE=${COUNT_FILE}
"

if [[ "${FUNCRUN}" != "" ]];then
  wlog_info "Run ${FUNCRUN}"
  set -v
  eval ${FUNCRUN}
  set +v
else

#  svg_create_vg "${LUNS}" ${METADATA_SIZE}
#  svg_test_lv_multi_pool $active
#  svg_del_all
svg_test_lv_multi_pool
fi
