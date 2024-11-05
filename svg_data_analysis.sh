#!/bin/bash
# Test result analysis and log merge 
set -e

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")
source ${WORK_PATH}/svg_common.sh

usage="$0 <testname> [log_dir]"
TEST_NAME=$1
LOG_DIR=${2:-"/home/vwrepo/kslog/$1"}

LOG_FILE=${LOG_FILE:-"${LOG_DIR}/main.log"}

if [ -z "${TEST_NAME}" ]; then
    echo "Please set testname"
    echo "$usage"
    return
fi

echo "TEST_NAME:${TEST_NAME}"
echo "LOG_DIR：${LOG_DIR}"
result=$LOG_DIR/${TEST_NAME}.result

###############################

cmd="cat ${LOG_DIR}/*.time|awk '{print \$1}'|awk '{sum += \$1} END {print sum}'"
echo "$cmd"
total=$(eval "$cmd")
cat ${LOG_DIR}/*.time|tee -a $result
echo -e "\nTotal of task:$total\n"|tee -a $result



cmd="cat ${LOG_DIR}/*.time|awk '{print \$1}'|sort|tail -n 1"
echo "$cmd"
max=$(eval "$cmd")
echo -e "\nMax of task:$max\n"|tee -a $result


cmd="cat ${LOG_DIR}/*.stg|awk -F : '{print \$3}'|awk '{sum += \$1} END {print sum}'"
echo "$cmd"
total=$(eval "$cmd")
cat ${LOG_DIR}/*.stg|tee -a $result
echo -e "\nTotal of stage:$total\n"|tee -a $result

echo "log merge"
kslog_merge_log ${LOG_FILE}
echo "over"