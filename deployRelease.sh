#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
BIN_DIR="${WORKSPACE}/${ACCOUNT}/config/bin"
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Add release tag and deployment to details
DETAIL_MESSAGE="deployment=r${BUILD_NUMBER}-${SEGMENT}, release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

cd ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    # Create the required Cloud Formation stack
    if [[ "${MODE}" != "update"    ]]; then ${BIN_DIR}/deleteStack.sh -t application -i -s ${CURRENT_SLICE}; fi
    if [[ "${MODE}" == "stopstart" ]]; then ${BIN_DIR}/createStack.sh -t application -s ${CURRENT_SLICE}; fi
    if [[ "${MODE}" == "update"    ]]; then ${BIN_DIR}/updateStack.sh -t application -s ${CURRENT_SLICE}; fi

    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
    	echo -e "\nStack deployment for ${CURRENT_SLICE} slice failed"
        exit
    fi
done

# All good
RESULT=0

