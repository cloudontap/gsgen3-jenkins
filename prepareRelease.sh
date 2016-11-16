#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Add deployment number to details
DETAIL_MESSAGE="deployment=${DEPLOYMENT_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# Process the config repo
cd ${WORKSPACE}/${AID}/config/${PRODUCT}

# Check for a deploy config reference
if [[ -f appsettings/${SEGMENT}/${BUILD_SLICE}/slice.ref ]]; then
    BUILD_SLICE="$(cat appsettings/${SEGMENT}/${BUILD_SLICE}/slice.ref)"
fi

# Ensure build.ref (if present) aligns with the requested code tag
if [[ -f appsettings/${SEGMENT}/${BUILD_SLICE}/build.ref ]]; then
    BUILD_REFERENCE=$(echo -n "${CODE_COMMIT} ${CODE_TAG}")
    if [[ "$(cat appsettings/${SEGMENT}/${BUILD_SLICE}/build.ref)" != "${BUILD_REFERENCE}" ]]; then
        echo -n "${BUILD_REFERENCE}" > appsettings/${SEGMENT}/${BUILD_SLICE}/build.ref
        ${JENKINS_DIR}/manageRepo.sh -p \
            -d . \
            -n config \
            -m "${DETAIL_MESSAGE}" \
            -b ${PRODUCT_CONFIG_REFERENCE}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi
fi
BIN_DIR="${WORKSPACE}/${AID}/config/bin"
cd solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do
    # Generate the application level template
	${BIN_DIR}/createApplicationTemplate.sh -c ${DEPLOYMENT_TAG} -s ${CURRENT_SLICE}
	RESULT=$?
	if [[ ${RESULT} -ne 0 ]]; then
 		echo "Can't generate the template for the ${CURRENT_SLICE} application slice, exiting..."
 		exit
	fi
done

# All ok so tag the config repo
${JENKINS_DIR}/manageRepo.sh -p \
    -d . \
    -n config \
    -t ${DEPLOYMENT_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	exit
fi

# Process the infrastructure repo
cd ${WORKSPACE}/${AID}/infrastructure/${PRODUCT}

# Commit the generated application templates
${JENKINS_DIR}/manageRepo.sh -p \
    -d . \
    -n config \
    -t ${DEPLOYMENT_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_INFRASTRUCTURE_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	exit
fi

# All good
RESULT=0