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

