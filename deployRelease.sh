#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Create the required Cloud Formation stack
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"
cd ${WORKSPACE}/${OAID}/config/${PROJECT}/solutions/${ENVIRONMENT}

if [[ "${MODE}" != "update"    ]]; then ${BIN_DIR}/deleteStack.sh -t application -i -s ${SLICE}; fi
if [[ "${MODE}" == "stopstart" ]]; then ${BIN_DIR}/createStack.sh -t application -s ${SLICE}; fi
if [[ "${MODE}" == "update"    ]]; then ${BIN_DIR}/updateStack.sh -t application -s ${SLICE}; fi

RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Stack deployment failed, exiting..."
	exit
fi

