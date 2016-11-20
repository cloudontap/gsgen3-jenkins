#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

cd ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    # Generate the deployment template for the required slice
    ${GENERATION_DIR}/createApplicationTemplate.sh -c ${PRODUCT_CONFIG_COMMIT} -s ${CURRENT_SLICE}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo -e "\nTemplate build for ${CURRENT_SLICE} slice failed"
	    exit
    fi

    if [[ "${MODE}" != "update"    ]]; then ${GENERATION_DIR}/deleteStack.sh -t application -i -s ${CURRENT_SLICE}; fi
    if [[ "${MODE}" == "stopstart" ]]; then 
        ${GENERATION_DIR}/createStack.sh -t application -s ${CURRENT_SLICE}
        RESULT=$?
    fi
    if [[ "${MODE}" == "update"    ]]; then 
        ${GENERATION_DIR}/updateStack.sh -t application -s ${CURRENT_SLICE}
        RESULT=$?
    fi

    if [[ ${RESULT} -ne 0 ]]; then
    	echo -e "\nStack deployment for ${CURRENT_SLICE} slice failed"
	    exit
    fi
done

#Finished
RESULT=0

