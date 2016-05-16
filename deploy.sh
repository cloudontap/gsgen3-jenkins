#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Generate the deployment template for the required slice
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"
cd ${WORKSPACE}/${OAID}/config/${PROJECT}/solutions/${ENVIRONMENT}

${BIN_DIR}/createApplicationTemplate.sh -c ${CONFIG_REFERENCE} -s ${SLICE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Template build failed, exiting..."
	exit
fi

if [[ "${MODE}" != "update"    ]]; then ${BIN_DIR}/deleteStack.sh -t application -i -s ${SLICE}; fi

if [[ "${MODE}" == "stopstart" ]]; then ${BIN_DIR}/createStack.sh -t application -s ${SLICE}; fi
RESULT=$?

if [[ "${MODE}" == "update"    ]]; then 
	${BIN_DIR}/updateStack.sh -t application -s ${SLICE}
    RESULT=$?
fi

if [[ ${RESULT} -ne 0 ]]; then
	echo "Stack deployment failed, exiting..."
	exit
fi

