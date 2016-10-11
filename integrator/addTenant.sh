#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

BIN_DIR="${WORKSPACE}/gsgen"
cd ${WORKSPACE}/${CID}

# Add the tenant
${BIN_DIR}/integrator/addTenant.sh
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't add tenant, exiting..."
	exit
fi

# Save the additions to the repo
${GSGEN_JENKINS}/manageRepo.sh -n ${CID_REPO} -m "Added tenant ${TID}"
RESULT=$?
