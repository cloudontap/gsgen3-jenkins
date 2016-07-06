#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Add deployment number to details
DETAIL_MESSAGE="deployment=${DEPLOYMENT_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# Determine the slice or slices to process
# SLICE_LIST and BUILD_SLICE may already be defined in which case SLICE and SLICES
# are ignored.
SLICE_LIST="${SLICE_LIST:-$SLICE}"
SLICE_LIST="${SLICE_LIST:-$SLICES}"  
BUILD_SLICE="${BUILD_SLICE:-$SLICE}"
SLICE_ARRAY=($SLICE_LIST)
BUILD_SLICE="${BUILD_SLICE:-${SLICE_ARRAY[0]}}"

# Process the config repo
cd ${WORKSPACE}/${OAID}/config/${PROJECT}

# Ensure git knows who we are
git config user.name  "${GIT_USER}"
git config user.email "${GIT_EMAIL}"

# Check for a deploy config reference
if [[ -f deployments/${SEGMENT}/${BUILD_SLICE}/slice.ref ]]; then
    BUILD_SLICE="$(cat deployments/${SEGMENT}/${BUILD_SLICE}/slice.ref)"
fi

# Ensure build.ref (if present) aligns with the requested code tag
if [[ -f deployments/${SEGMENT}/${BUILD_SLICE}/build.ref ]]; then
    BUILD_REFERENCE=$(echo -n "${CODE_COMMIT} ${CODE_TAG}")
    if [[ "$(cat deployments/${SEGMENT}/${BUILD_SLICE}/build.ref)" != "${BUILD_REFERENCE}" ]]; then
        echo -n "${BUILD_REFERENCE}" > deployments/${SEGMENT}/${BUILD_SLICE}/build.ref
        git add *; git commit -m "${DETAIL_MESSAGE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't commit the build reference to the config repo, exiting..."
            exit
        fi
    fi
fi
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"
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
echo "Adding tag \"${DEPLOYMENT_TAG}\" to the config repo..."
git tag -a ${DEPLOYMENT_TAG} -m "${DETAIL_MESSAGE}"
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't tag the config repo, exiting..."
	exit
fi
git push --tags origin ${PROJECT_CONFIG_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't push the new tag to the config repo, exiting..."
	exit
fi

# Process the infrastructure repo
cd ${WORKSPACE}/${OAID}/infrastructure/${PROJECT}

# Ensure git knows who we are
git config user.name  "${GIT_USER}"
git config user.email "${GIT_EMAIL}"

# Commit the generated application templates
echo "Committing application templates to the infrastructure repo..."
git add *; git commit -m "${DETAIL_MESSAGE}"
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't commit the application templates to the infrastructure repo, exiting..."
	exit
fi

# Tag the infrastructure repo
echo "Adding tag \"${DEPLOYMENT_TAG}\" to the infrastructure repo..."
git tag -a ${DEPLOYMENT_TAG} -m "${DETAIL_MESSAGE}"
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't tag the infrastructure repo, exiting..."
	exit
fi
git push --tags origin ${PROJECT_INFRASTRUCTURE_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't push the new tag and application templates to the infrastructure repo, exiting..."
	exit
fi

