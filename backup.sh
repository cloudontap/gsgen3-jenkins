#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Formulate optional parameters
SNAPSHOT_OPTS=
if [[ -n "${SNAPSHOT_COUNT}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -r ${SNAPSHOT_COUNT}"
fi
if [[ -n "${SNAPSHOT_AGE}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -a ${SNAPSHOT_AGE}"
fi

# Snapshot the database
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"
cd ${WORKSPACE}/${OAID}/config/solutions/${PROJECT}/${ENVIRONMENT}

${BIN_DIR}/snapshotRDSDatabase.sh -i ${COMPONENT} -s b${BUILD_NUMBER} ${SNAPSHOT_OPTS}
RESULT=$?

if [[ ${RESULT} -ne 0 ]]; then
	echo "Snapshot of ${ENVIRONMENT}/${COMPONENT} failed, exiting..."
	exit
fi

