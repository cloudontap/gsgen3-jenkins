#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Tag the build as stable
export REMOTE_REPO="${PROJECT}/${CODE_COMMIT}"
export LOCAL_TAG="stable"
export IMAGE_SOURCE="local"
${GSGEN_JENKINS}/manageDockerImage.sh
RESULT=$?

