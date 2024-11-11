#!/bin/bash
WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 3 host,1 vg, 3 task, LV 6000"
echo "Each task handles same vg"
echo "You need to open 3 consoles to run commands respectively"

stamp=$(date '+%d%H%M')
TEST_NAME=${1:-"h3v1t3-$stamp"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}
rest=${2:-"1"}
number=${3:-2000}
###################
if [ "$rest" == "1" ]; then
    #echo host need run
    ./svg_test.sh -e "svg_vg_create -v ksvg1 -d /dev/sdb "
fi
###################
rm ${LOG_DIR} -rf
for ((i = 0; i < 3; i++)); do
    start=$((i * 2000))
    echo "./svg_test.sh -v ksvg1 -t $TEST_NAME -e \"svg_lv_create -n 2000 -s $start -u 1000 \""
done
###################

echo "./svg_data_analysis.sh $TEST_NAME"
alianame=$(echo "$TEST_NAME"|cut -f 1 -d "-")
echo "wbug ks-rhel/$alianame ${LOG_DIR}/*"
