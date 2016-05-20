#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

. ${GSGEN_JENKINS}/setContext.sh

# Ensure DEPLOYMENT_NUMBER have been provided
if [[ "${DEPLOYMENT_NUMBER}" == "" ]]; then
	echo "Job requires the deployment number, exiting..."
    RESULT=1
    exit
fi

# Generate the deployment tag
export DEPLOY_TAG="d${DEPLOYMENT_NUMBER}-${ENVIRONMENT}"
echo "DEPLOY_TAG=${DEPLOY_TAG}" >> ${WORKSPACE}/context.properties

# Construct the tree based on the deployment tags
${GSGEN_JENKINS}/constructTree.sh -c ${DEPLOY_TAG} -i ${DEPLOY_TAG}
RESULT=$?

