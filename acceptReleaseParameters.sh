#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure DEPLOYMENT_NUMBER have been provided
if [[ "${DEPLOYMENT_NUMBER}" == "" ]]; then
	echo -e "\nJob requires the deployment number"
    RESULT=1
    exit
fi

# All good
RESULT=0


