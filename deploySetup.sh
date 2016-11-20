#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Include the current build image references in the detail message
cd ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}

for CURRENT_SLICE in ${SLICE_LIST}; do
    BUILD_FILE="appsettings/${SEGMENT}/${CURRENT_SLICE}/build.ref"
    if [[ -e ${BUILD_FILE} ]]; then
        BUILD_REFERENCE="$(cat ${BUILD_FILE})"
        if [[ -n "${BUILD_REFERENCE}" ]]; then
            DETAIL_MESSAGE="${DETAIL_MESSAGE}, ${CURRENT_SLICE}=${BUILD_REFERENCE:0:8}"
        fi
    fi
done

echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# All good
RESULT=0
