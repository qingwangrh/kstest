#!/bin/bash

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 1 host,1 vg, 1 task, LV 6000"

stamp=$(date '+%d%H%M')
TEST_NAME=${1:-"h1v1t1-$stamp"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}
rest=${2:-"1"}
number=${3:-6000}
###################
if [ "$rest" == "1" ]; then
    ./svg_test.sh -e "svg_vg_reset -v ksvg1 -d /dev/sdb "
fi
###################
rm ${LOG_DIR} -rf

./svg_test.sh -t $TEST_NAME -n 6000 -e "svg_lv_create -v ksvg1"

###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

./svg_data_analysis.sh $TEST_NAME
alianame=$(echo "$TEST_NAME"|cut -f 1 -d "-")
echo "wbug ks-rhel/$alianame ${LOG_DIR}/*"
