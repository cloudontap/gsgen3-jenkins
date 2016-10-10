#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

BIN_DIR="${WORKSPACE}/gsgen"
cd ${WORKSPACE}/${CID}

# Add the tenant
${BIN_DIR}/integrator/addTenant.sh
RESULT=$?

