#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Determine the code commit used
BUILD_REFERENCE="$(cat ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}/appsettings/$SEGMENT/${BUILD_SLICE}/build.ref)"

CODE_COMMIT="$(echo ${BUILD_REFERENCE} | cut -d' ' -f 1)"
CODE_TAG="$(echo ${BUILD_REFERENCE} | cut -d' ' -f 2)"

# Add extra details
DETAIL_MESSAGE="deployment=${DEPLOYMENT_TAG}, ${DETAIL_MESSAGE}, code=${CODE_TAG} (${CODE_COMMIT})"

# Save for next step
echo "BUILD_REFERENCE=${BUILD_REFERENCE}" >> ${WORKSPACE}/context.properties
echo "CODE_COMMIT=${CODE_COMMIT}" >> ${WORKSPACE}/context.properties
echo "CODE_TAG=${CODE_TAG}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# All good
RESULT=0

