#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
JENKINS_DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && cd .. && pwd )
GSGEN_DIR="${WORKSPACE}/gsgen"
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

cd ${WORKSPACE}/${INTEGRATOR}

# Add the tenant
${GSGEN_DIR}/integrator/addTenant.sh
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't add tenant, exiting..."
	exit
fi

# Save the additions to the repo
${JENKINS_DIR}/manageRepo.sh -n ${CID_REPO} -m "Added tenant ${TID}"
RESULT=$?
