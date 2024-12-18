#!/bin/bash

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 1 host,1 vg, 1 task, LV 6000"

stamp=$(date '+%d%H%M')
TEST_NAME=${1:-"combination-$stamp"}

LOG_ROOTDIR=/home/vwrepo/kslog/${TEST_NAME}

rest=${2:-"1"}
number=${3:-6000}
###################
if [ "$rest" == "1" ]; then
    ./svg_test.sh -e "svg_vg_reset -v ksvg1 -d /dev/sdb "
fi

###################
rm $LOG_ROOTDIR -rf
for ((i = 0; i < 6; i++)); do
    start=$((i * 1000))
    ./svg_test.sh -r ${LOG_ROOTDIR} -t create -e "svg_lv_create -v ksvg1 -n 1000 -s $start -o '-an' -u 1000"
    ./svg_test.sh -r ${LOG_ROOTDIR} -t change -e "svg_lv_change -v ksvg1 -n 1000 -s $start -o '-ay' -u 1000"
    ./svg_test.sh -r ${LOG_ROOTDIR} -t extend -e "svg_lv_extend -v ksvg1 -n 1000 -s $start -u 1000"
done


###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

./svg_data_analysis.sh create ${LOG_ROOTDIR}/create
./svg_data_analysis.sh change ${LOG_ROOTDIR}/change
./svg_data_analysis.sh extend ${LOG_ROOTDIR}/extend


alianame=$(echo "$TEST_NAME"|cut -f 1 -d "-")
echo "wbug ks-rhel/$alianame ${LOG_DIR}/*"

