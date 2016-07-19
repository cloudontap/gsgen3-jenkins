#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure CODE_TAG have been provided
if [[ -z "${CODE_TAG}" ]]; then
	echo "Job requires the code tag, exiting..."
    exit
fi

# Get the commit corresponding to the tag
TAG_COMMIT=$(git ls-remote -t https://${!PROJECT_CODE_GIT_CREDENTIALS_VAR}@${PROJECT_CODE_GIT_DNS}/${PROJECT_CODE_GIT_ORG}/${PROJECT_CODE_REPO} "${CODE_TAG}" | cut -f 1)
CODE_COMMIT=$(git ls-remote -t https://${!PROJECT_CODE_GIT_CREDENTIALS_VAR}@${PROJECT_CODE_GIT_DNS}/${PROJECT_CODE_GIT_ORG}/${PROJECT_CODE_REPO} "${CODE_TAG}^{}" | cut -f 1)
if [[ -z "${CODE_COMMIT}" ]]; then
    echo "Code tag not found in the code repo, exiting..."
 	exit
fi

# Fetch other info about the tag
# We are using a github api here to avoid having to pull in the whole repo - 
# git currently doesn't have a command to query the message of a remote tag
CODE_COMMIT_SHORT="${CODE_COMMIT:0:8}"
CODE_TAG_MESSAGE=$(curl -s https://${!PROJECT_CODE_GIT_CREDENTIALS_VAR}@${PROJECT_CODE_GIT_API_DNS}/repos/${PROJECT_CODE_REPO}/git/tags/${TAG_COMMIT} | jq .message | tr -d '"')
if [[ -z "${CODE_TAG_MESSAGE}" || ("${CODE_TAG_MESSAGE}" == "Not Found") ]]; then
	echo "Tag message not found in the code repo, exiting..."
	exit
fi

# Details of job
DETAIL_MESSAGE="${DETAIL_MESSAGE}, code=${CODE_TAG} (${CODE_COMMIT_SHORT})"

# Save for future steps
echo "CODE_TAG_MESSAGE=${CODE_TAG_MESSAGE}" >> ${WORKSPACE}/context.properties
echo "CODE_COMMIT=${CODE_COMMIT}" >> ${WORKSPACE}/context.properties
echo "CODE_COMMIT_SHORT=${CODE_COMMIT_SHORT}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# Confirm the commit built successfully into a docker image
if [[ (-z "${BUILD_SLICE}" ) || ( -n "${DOCKER_INHIBIT_SLICE_IN_REPO}" ) ]]; then
    export REMOTE_REPO="${PROJECT}/${CODE_COMMIT}"
else
    export REMOTE_REPO="${PROJECT}/${BUILD_SLICE}-${CODE_COMMIT}"
fi
${GSGEN_JENKINS}/manageDockerImage.sh -c -i ${REMOTE_REPO}
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then
    echo "Image ${REMOTE_REPO} not found. Was the build successful?"
    exit
fi
