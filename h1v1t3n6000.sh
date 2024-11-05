#!/bin/bash
WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 1 host,1 vg, 3 task, LV 6000"
echo "You need to open 3 consoles to run commands respectively"

TEST_NAME=${1:-"h1v1t3n6000"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}

###################
echo "./svg_test.sh -e "svg_vg_reset -v ksvg1 -d /dev/sdb""
###################
for ((i = 0; i < 3; i++)); do
    start=$((i * 2000))
    echo "./svg_test.sh -t $TEST_NAME -e \"svg_lv_create  -n 2000 -s $start\""
done
###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

./svg_data_analysis.sh $TEST_NAME
echo "wbug ks-rhel/$TEST_NAME ${LOG_DIR}"
