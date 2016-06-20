#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Ensure DEPLOYMENT_NUMBER have been provided
if [[ "${DEPLOYMENT_NUMBER}" == "" ]]; then
	echo "Job requires the deployment number, exiting..."
    RESULT=1
    exit
fi

. ${GSGEN_JENKINS}/setContext.sh

# Construct the tree based on the deployment tag
${GSGEN_JENKINS}/constructTree.sh -c ${DEPLOYMENT_TAG} -i ${DEPLOYMENT_TAG}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
 	exit
fi

# Determine the code commit used
BUILD_REFERENCE="$(cat ${WORKSPACE}/${OAID}/config/${PROJECT}/deployments/$SEGMENT/${BUILD_SLICE}/build.ref)"

CODE_COMMIT="$(echo ${BUILD_REFERENCE} | cut -d' ' -f 1)"
CODE_TAG="$(echo ${BUILD_REFERENCE} | cut -d' ' -f 2)"

# Add extra details
DETAIL_MESSAGE="Deployment ${DEPLOYMENT_TAG}, ${DETAIL_MESSAGE}, code ${CODE_TAG} (${CODE_COMMIT})"

# Save for next step
echo "BUILD_REFERENCE=${BUILD_REFERENCE}" >> ${WORKSPACE}/context.properties
echo "CODE_COMMIT=${CODE_COMMIT}" >> ${WORKSPACE}/context.properties
echo "CODE_TAG=${CODE_TAG}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

