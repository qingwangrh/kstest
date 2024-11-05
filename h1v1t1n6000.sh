#!/bin/bash

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 1 host,1 vg, 1 task, LV 6000"

TEST_NAME=${1:-"h1v1t1n6000"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}
rm ${LOG_DIR}  -rf

###################
./svg_test.sh -e "svg_vg_reset -v ksvg1 -d /dev/sdb"
###################

./svg_test.sh -t $TEST_NAME -n 6000 -e "svg_lv_create"

###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

./svg_data_analysis.sh $TEST_NAME
echo "wbug ks-rhel/$TEST_NAME ${LOG_DIR}"

