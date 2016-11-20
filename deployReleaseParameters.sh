#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure RELEASE_NUMBER have been provided
if [[ "${RELEASE_NUMBER}" == "" ]]; then
	echo -e "\nJob requires the release number to use in the deployment"
    exit
fi

# Ensure at least one slice has been provided
if [[ ( -z "${SLICE}" ) && ( -z "${SLICES}" ) ]]; then
	echo -e "\nJob requires at least one slice"
    exit
fi

# Don't forget -c ${RELEASE_TAG} -i ${RELEASE_TAG} on constructTree.sh

# All good
RESULT=0

