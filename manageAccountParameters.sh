#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Determine the AID
if [[ -z "${AID}" ]]; then
    echo "The AID must be provided"
    RESULT=1
    exit
fi

