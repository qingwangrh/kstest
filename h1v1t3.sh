#!/bin/bash
WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

usage="$0 <testname> [reset]  [number]"

echo "Test: lvcreate 1 host,1 vg, 3 task, LV 6000"
echo "Each task handles respective LV scope"
echo "You need to open 3 consoles to run commands respectively"

TEST_NAME=${1:-"h1v1t3"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}
rest=${2:-"1"}
number=${3:-2000}

###################
if [ "$rest" == "1" ]; then
    echo "./svg_test.sh -e "svg_vg_reset -v ksvg1 -d /dev/sdb""
fi
###################
rm ${LOG_DIR} -rf
for ((i = 0; i < 3; i++)); do
    start=$((i * 2000))
    echo "./svg_test.sh -t $TEST_NAME -e \"svg_lv_create -v ksvg1 -n 2000 -s $start\""
done
###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

echo "./svg_data_analysis.sh $TEST_NAME"
echo "wbug ks-rhel/$TEST_NAME ${LOG_DIR}/*"
