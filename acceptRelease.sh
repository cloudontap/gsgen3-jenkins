#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Tag the build as stable
${AUTOMATION_DIR}/manageDocker.sh -k -r "stable"
RESULT=$?

