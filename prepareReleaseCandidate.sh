#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Generate the deployment tag
DEPLOY_TAG="d${BUILD_NUMBER}-${ENVIRONMENT}"
DEPLOY_MESSAGE="Prepare deployment ${DEPLOY_TAG} for ${PROJECT}/${ENVIRONMENT}, based on ${CODE_TAG} (${GIT_COMMIT_SHORT}) of the code"

# Process the config repo
cd ${WORKSPACE}/${OAID}/config/${PROJECT}

# Ensure git knows who we are
git config user.name  "${GIT_USER}"
git config user.email "${GIT_EMAIL}"

# Ensure build.ref aligns with the requested code tag
BUILD_REFERENCE=$(echo -n "${GIT_COMMIT} ${CODE_TAG}")
if [[ "$(cat deployments/${ENVIRONMENT}/${BUILD_SLICE}/build.ref)" != "${BUILD_REFERENCE}" ]]; then
	echo -n "${BUILD_REFERENCE}" > deployments/${ENVIRONMENT}/${BUILD_SLICE}/build.ref
	git add *; git commit -m "${DEPLOY_MESSAGE}"
	RESULT=$?
	if [[ ${RESULT} -ne 0 ]]; then
		echo "Can't commit the build reference to the config repo, exiting..."
		exit
	fi
fi

# Generate the application level templates
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"
cd solutions/${ENVIRONMENT}

for SLICE in ${SLICE_LIST}; do
	${BIN_DIR}/createApplicationTemplate.sh -c ${DEPLOY_TAG} -s ${SLICE}
	RESULT=$?
	if [[ ${RESULT} -ne 0 ]]; then
 		echo "Can't generate the template for the ${SLICE} application slice, exiting..."
 		exit
	fi
done

# All ok so tag the config repo
echo "Adding tag \"${DEPLOY_TAG}\" to the config repo..."
git tag -a ${DEPLOY_TAG} -m "${DEPLOY_MESSAGE}"
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
git add *; git commit -m "${DEPLOY_MESSAGE}"
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't commit the application templates to the infrastructure repo, exiting..."
	exit
fi

# Tag the infrastructure repo
echo "Adding tag \"${DEPLOY_TAG}\" to the infrastructure repo..."
git tag -a ${DEPLOY_TAG} -m "${DEPLOY_MESSAGE}"
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

