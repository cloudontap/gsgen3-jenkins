#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Ensure CODE_TAG have been provided
if [[ "${CODE_TAG}" == "" ]]; then
	echo "Job requires the code tag, exiting..."
    RESULT=1
    exit
fi

# Pull in the code repo
git clone https://${GITHUB_USER}:${GITHUB_PASS}@${PROJECT_CODE_REPO} -b ${CODE_BRANCH} code
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
 	echo "Can't fetch the code repo, exiting..."
 	exit
fi
cd code

# Confirm the tag is present
CODE_TAG_MESSAGE=$(git tag -l ${CODE_TAG} -n1 | tr -s " " | cut -d " " -f 2-)
if [[ "${CODE_TAG_MESSAGE}" == "" ]]; then
	echo "Code tag not found in the code repo, exiting..."
   	RESULT=1
	exit
fi

# Determine the commit matching the tag in the code repo 
CODE_COMMIT=$(git rev-list -n 1 ${CODE_TAG})
CODE_COMMIT_SHORT=$(git rev-list -n 1 --abbrev-commit ${CODE_TAG})

# Details of job
DETAIL_MESSAGE="${DETAIL_MESSAGE}, code=${CODE_TAG} (${CODE_COMMIT_SHORT})"

# Save for future steps
echo "CODE_TAG_MESSAGE=${CODE_TAG_MESSAGE}" >> ${WORKSPACE}/context.properties
echo "CODE_COMMIT=${CODE_COMMIT}" >> ${WORKSPACE}/context.properties
echo "CODE_COMMIT_SHORT=${CODE_COMMIT_SHORT}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# Confirm the commit built successfully into a docker image
export REMOTE_REPO="${PROJECT}/${CODE_COMMIT}"
${GSGEN_JENKINS}/manageDockerImage.sh -c
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then
    echo "Image ${REMOTE_REPO} not found. Was the build successful?"
fi
