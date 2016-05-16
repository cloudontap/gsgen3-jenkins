#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

. ${GSGEN_JENKINS}/setContext.sh

${GSGEN_JENKINS}/constructTree.sh
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then
    exit
fi

# Determine the required build image
cd ${WORKSPACE}/${OAID}/config/${PROJECT}
BUILD_FILE="deployments/${ENVIRONMENT}/${SLICE}/build.ref"
if [[ -e ${BUILD_FILE} ]]; then
    echo "BUILD_REFERENCE=$(cat ${BUILD_FILE})" >> ${WORKSPACE}/context.ref
fi

# Generate the notification message information
if [[ -n "${BUILD_REFERENCE}" ]]; then
    echo "MESSAGE=Slice $SLICE (build $BUILD_REFERENCE) to $ENVIRONMENT environment" >> ${WORKSPACE}/context.ref
else
    echo "MESSAGE=Slice $SLICE to $ENVIRONMENT environment" >> ${WORKSPACE}/context.ref
fi

