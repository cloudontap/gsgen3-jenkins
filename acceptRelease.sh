#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Tag the build as stable
${GSGEN_JENKINS}/manageDocker.sh -k -r "stable"
RESULT=$?

