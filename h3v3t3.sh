#!/bin/bash
WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

echo "Test: lvcreate 3 host,3 vg, 3 task, LV 6000"
echo "Each task handles respective vg"
echo "You need to open 3 consoles to run commands respectively"

TEST_NAME=${1:-"h3v3t3"}
LOG_ROOTDIR=/home/vwrepo/kslog
LOG_DIR=${LOG_DIR:-${LOG_ROOTDIR}/${TEST_NAME}}
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}
rest=${2:-"0"}
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
# create vgs on one host
# other host run vgchange --lockstart  
###################
rm ${LOG_DIR} -rf
for ((i = 0; i < 3; i++)); do
    start=$((i * 2000))
    echo "./svg_test.sh -v ${vgs[$i]} -t $TEST_NAME -e \"svg_lv_create -n 2000 -s $start -u 1000 \""
done
###################

echo "./svg_data_analysis.sh $TEST_NAME"
echo "wbug ks-rhel/$TEST_NAME ${LOG_DIR}/*"
