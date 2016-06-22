#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z ${GIT_COMMIT} ]]; then
  echo "This job requires GIT_COMMIT value, exiting..."
  RESULT=1
  exit
fi


