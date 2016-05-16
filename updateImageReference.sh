#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z ${GIT_COMMIT} ]]; then
  echo "This job requires GIT_COMMIT value, exiting..."
  RESULT=1
  exit
fi

. ${GSGEN_JENKINS}/setContext.sh

${GSGEN_JENKINS}/constructTree.sh
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then
    echo "Construction of the account/project directory tree failed"
    exit
fi

cd ${WORKSPACE}/${OAID}/config/${PROJECT}/deployments/${ENVIRONMENT}/${SLICE}

REFFILE="build.ref"
REF=`cat ${REFFILE}`

if [[ "${REF}" == "${GIT_COMMIT}" ]]; then
  echo "The current reference is the same, exiting..."
  RESULT=1
  exit
fi

# Ensure git knows who we are
git config user.name  "${GIT_USER}"
git config user.email "${GIT_EMAIL}"

echo ${GIT_COMMIT} > ${REFFILE}
git commit -a -m "Change build.ref for ${ENVIRONMENT}/${SLICE} to the value: ${GIT_COMMIT}"
git push origin ${PROJECT_CONFIG_REFERENCE}

if [[ "$AUTODEPLOY" != "true" ]]; then
  echo "AUTODEPLOY is not true, triggering exit ..."
  RESULT=2
  exit
fi
