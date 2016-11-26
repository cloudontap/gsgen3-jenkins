#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# No parameters at this stage but we need to update the DETAIL_MESSAGE

# Add release number to details
DETAIL_MESSAGE="release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# All good
RESULT=0