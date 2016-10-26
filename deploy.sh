#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

BIN_DIR="${WORKSPACE}/${AID}/config/bin"
cd ${WORKSPACE}/${AID}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    # Generate the deployment template for the required slice
    ${BIN_DIR}/createApplicationTemplate.sh -c ${PRODUCT_CONFIG_COMMIT} -s ${CURRENT_SLICE}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Template build for ${CURRENT_SLICE} slice failed, exiting..."
	    exit
    fi

    if [[ "${MODE}" != "update"    ]]; then ${BIN_DIR}/deleteStack.sh -t application -i -s ${CURRENT_SLICE}; fi
    if [[ "${MODE}" == "stopstart" ]]; then 
        ${BIN_DIR}/createStack.sh -t application -s ${CURRENT_SLICE}
        RESULT=$?
    fi
    if [[ "${MODE}" == "update"    ]]; then 
        ${BIN_DIR}/updateStack.sh -t application -s ${CURRENT_SLICE}
        RESULT=$?
    fi

    if [[ ${RESULT} -ne 0 ]]; then
    	echo "Stack deployment for ${CURRENT_SLICE} slice failed, exiting..."
	    exit
    fi
done

#Finished
RESULT=0

