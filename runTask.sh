#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

BIN_DIR="${WORKSPACE}/${OAID}/config/bin"
cd ${WORKSPACE}/${OAID}/config/${PROJECT}/solutions/${SEGMENT}

# Build up the additional enviroment variables required
ENVS=""
for i in "" $(seq 2 20); do
    ENV_NAME="TASK_ENV${i}"
    ENV_VALUE="TASK_VALUE${i}"
    if [[ -n "${!ENV_NAME}" ]]; then
        if [[ -n "${GSGEN_DEBUG}" ]]; then echo ${!ENV_NAME}; fi
        if [[ -n "${GSGEN_DEBUG}" ]]; then echo ${!ENV_VALUE}; fi
        ENVS="${ENVS} -e ${!ENV_NAME} -v \"${!ENV_VALUE}\""
    fi 
done

if [[ -n "${GSGEN_DEBUG}" ]]; then echo ${ENVS}; fi

# Create the required task
${BIN_DIR}/runTask.sh -t "${TASK_TIER}" -i "${TASK_COMPONENT}" -w "${TASK}" ${ENVS}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Running of task failed, exiting..."
	exit
fi

