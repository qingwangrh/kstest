#!/bin/bash
WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 1 host,3 vg, 1 task, LV 6000"

TEST_NAME=${1:-"h1v3t1n6000"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}
rest=${2:-"1"}
number=${3:-2000}

###################
vgs=(ksvg1 ksvg2 ksvg3)
luns=(/dev/sdb /dev/sdc /dev/sdd)

if [ "$rest" == "1" ]; then
    for ((i = 2; i >=0; i--)); do
        ./svg_test.sh -e "svg_vg_remove -v ${vgs[$i]} "
    done
    for ((i = 0; i < 3; i++)); do
        ./svg_test.sh -e "svg_vg_create -v ${vgs[$i]} -d ${luns[$i]}"
    done
fi

###################
rm ${LOG_DIR} -rf
for ((i = 0; i < 3; i++)); do
    start=$((i * 2000))
    ./svg_test.sh -v ${vgs[$i]} -t $TEST_NAME -e "svg_lv_create -n 2000 -s $start -u 1000"
done
###################
echo "./svg_test.sh -e \"svg_vg_reset -v ksvg1 -d /dev/sdb\""

./svg_data_analysis.sh $TEST_NAME
echo "wbug ks-rhel/$TEST_NAME ${LOG_DIR}/*"
