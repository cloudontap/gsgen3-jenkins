#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

BIN_DIR="${WORKSPACE}/${AID}/config/bin"
cd ${WORKSPACE}/${AID}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    # Create the required Cloud Formation stack
    if [[ "${MODE}" != "update"    ]]; then ${BIN_DIR}/deleteStack.sh -t application -i -s ${CURRENT_SLICE}; fi
    if [[ "${MODE}" == "stopstart" ]]; then ${BIN_DIR}/createStack.sh -t application -s ${CURRENT_SLICE}; fi
    if [[ "${MODE}" == "update"    ]]; then ${BIN_DIR}/updateStack.sh -t application -s ${CURRENT_SLICE}; fi

    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
    	echo "Stack deployment for ${CURRENT_SLICE} slice failed, exiting..."
        exit
    fi
done

#Finished
RESULT=0

