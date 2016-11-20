#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Check the current reference value
cd ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}

if [[ -f "appsettings/${SEGMENT}/${SLICE}/slice.ref" ]]; then
    REFERENCED_SLICE=$(cat "appsettings/${SEGMENT}/${SLICE}/slice.ref")
    echo -e "\nSlice references the slice ${REFERENCED_SLICE}"
    exit
fi

BUILD_FILE="appsettings/${SEGMENT}/${SLICE}/build.ref"
if [[ "$(cat ${BUILD_FILE})" == "${GIT_COMMIT}" ]]; then
  echo -e "\nThe requested reference value for slice $SLICE is already set"
  exit
fi

echo ${GIT_COMMIT} > ${BUILD_FILE}

${AUTOMATION_DIR}/manageRepo.sh -p \
    -d . \
    -n config \
    -m "Change build.ref for ${SEGMENT}/${SLICE} to the value: ${GIT_COMMIT}" \
    -b ${PRODUCT_CONFIG_REFERENCE}

if [[ "$AUTODEPLOY" != "true" ]]; then
  echo -e "\nAUTODEPLOY is not true, triggering exit"
  RESULT=2
  exit
fi

# All good
RESULT=0


