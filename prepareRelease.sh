#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
BIN_DIR="${WORKSPACE}/${ACCOUNT}/config/bin"
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Add release number to details
DETAIL_MESSAGE="release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# Prepare access to build info SLICE_ARRAY=(${SLICE_LIST})
CODE_TAG_ARRAY=(${CODE_TAG_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})

# Process each requested slice
for INDEX in $(seq 0 ${#SLICE_ARRAY[@]}); do

    # Next slice to process
    CURRENT_SLICE=${SLICE_ARRAY[$INDEX]}
    cd ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}
    
    # As we are now supporting multiple build updates in one release
    # assume that if updates to the build for the referenced slice are required,
    # it will be included in the slice list for the release
#    if [[ -f appsettings/${SEGMENT}/${CURRENT_SLICE}/slice.ref ]]; then
#        CURRENT_SLICE="$(cat appsettings/${SEGMENT}/${CURRENT_SLICE}/slice.ref)"
#    fi
    
    # Ensure build.ref (if present) aligns with the requested code tag
    if [[ -f appsettings/${SEGMENT}/${CURRENT_SLICE}/build.ref ]]; then
        BUILD_REFERENCE=$(echo -n "${CODE_COMMIT_ARRAY[$INDEX]} ${CODE_TAG_ARRAY[$INDEX]}")
        if [[ "$(cat appsettings/${SEGMENT}/${CURRENT_SLICE}/build.ref)" != "${BUILD_REFERENCE}" ]]; then
            echo -n "${BUILD_REFERENCE}" > appsettings/${SEGMENT}/${CURRENT_SLICE}/build.ref
        fi
    fi


    # Generate the application level template
    cd solutions/${SEGMENT}
	${BIN_DIR}/createApplicationTemplate.sh -c ${RELEASE_TAG} -s ${CURRENT_SLICE}
	RESULT=$?
	if [[ ${RESULT} -ne 0 ]]; then
 		echo -e "\nCan't generate the template for slice ${CURRENT_SLICE}"
 		exit
	fi
done

# All ok so tag the config repo
${JENKINS_DIR}/manageRepo.sh -p \
    -d ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT} \
    -n config \
    -t ${RELEASE_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	exit
fi

# Commit the generated application templates
${JENKINS_DIR}/manageRepo.sh -p \
    -d ${WORKSPACE}/${ACCOUNT}/infrastructure/${PRODUCT} \
    -n config \
    -t ${RELEASE_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_INFRASTRUCTURE_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	exit
fi

# All good
RESULT=0