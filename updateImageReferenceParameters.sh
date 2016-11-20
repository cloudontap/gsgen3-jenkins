#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z ${GIT_COMMIT} ]]; then
  echo -e "\nThis job requires GIT_COMMIT value"
  exit
fi

# All good
RESULT=0



