#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Use GIT_COMMIT as the build reference if its not explicitly defined 
BUILD_REFERENCE="${BUILD_REFERENCE:-$GIT_COMMIT}"

# Check the current reference value
cd ${WORKSPACE}/${OAID}/config/${PROJECT}
BUILD_FILE="deployments/${SEGMENT}/${SLICE}/build.ref"
if [[ "$(cat ${BUILD_FILE})" == "${BUILD_REFERENCE}" ]]; then
  echo "The current reference is the same, exiting..."
  RESULT=1
  exit
fi

# Ensure git knows who we are
git config user.name  "${GIT_USER}"
git config user.email "${GIT_EMAIL}"

echo ${BUILD_REFERENCE} > ${BUILD_FILE}
git commit -a -m "Change build.ref for ${SEGMENT}/${SLICE} to the value: ${BUILD_REFERENCE}"
git push origin ${PROJECT_CONFIG_REFERENCE}

if [[ "$AUTODEPLOY" != "true" ]]; then
  echo "AUTODEPLOY is not true, triggering exit ..."
  RESULT=2
  exit
fi

