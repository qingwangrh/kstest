#!/bin/bash

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 1 host,1 vg, 1 task, LV 6000"

TEST_NAME=${1:-"combination"}
LOG_ROOTDIR=/home/vwrepo/kslog/${TEST_NAME}

rest=${2:-"1"}
number=${3:-6000}
###################
if [ "$rest" == "1" ]; then
    ./svg_test.sh -e "svg_vg_reset -v ksvg1 -d /dev/sdb "
fi

###################

for ((i = 0; i < 6; i++)); do
    start=$((i * 1000))
    ./svg_test.sh -r ${LOG_ROOTDIR} -t create -e "svg_lv_create -v ksvg1 -n 1000 -s $start -o '-an'"
    ./svg_test.sh -r ${LOG_ROOTDIR} -t change -e "svg_lv_change -v ksvg1 -n 1000 -s $start -o '-ay'"
    ./svg_test.sh -r ${LOG_ROOTDIR} -t extend -e "svg_lv_extend -v ksvg1 -n 1000 -s $start"
done


###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

./svg_data_analysis.sh create ${LOG_ROOTDIR}/create
./svg_data_analysis.sh change ${LOG_ROOTDIR}/change
./svg_data_analysis.sh extend ${LOG_ROOTDIR}/extend
echo "wbug ks-rhel/$TEST_NAME/ ${LOG_ROOTDIR}/*"
