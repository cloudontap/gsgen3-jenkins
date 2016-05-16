#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

. ${GSGEN_JENKINS}/setContext.sh

${GSGEN_JENKINS}/constructTree.sh
RESULT=$?

