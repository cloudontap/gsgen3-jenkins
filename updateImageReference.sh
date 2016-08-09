#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Check the current reference value
cd ${WORKSPACE}/${AID}/config/${PRODUCT}
BUILD_FILE="deployments/${SEGMENT}/${SLICE}/build.ref"
if [[ "$(cat ${BUILD_FILE})" == "${GIT_COMMIT}" ]]; then
  echo "The current reference is the same, exiting..."
  RESULT=1
  exit
fi

# Ensure git knows who we are
git config user.name  "${GIT_USER}"
git config user.email "${GIT_EMAIL}"

echo ${GIT_COMMIT} > ${BUILD_FILE}
git commit -a -m "Change build.ref for ${SEGMENT}/${SLICE} to the value: ${GIT_COMMIT}"
git push origin ${PRODUCT_CONFIG_REFERENCE}

if [[ "$AUTODEPLOY" != "true" ]]; then
  echo "AUTODEPLOY is not true, triggering exit ..."
  RESULT=2
  exit
fi

