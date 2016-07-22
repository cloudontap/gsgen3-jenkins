#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z "${SLICE}" ]]; then
    if [ -e slice.ref ]; then
        SLICE=`cat slice.ref`
    fi
fi

# Perform checks for Docker packaging
if [[ -f Dockerfile ]]; then
    ${GSGEN_JENKINS}/manageDocker.sh -c -s ${SLICE}
    RESULT=$?
    if [[ "${RESULT}" -eq 0 ]]; then
        RESULT=1
        exit
    fi
fi

# TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker

npm install --unsafe-perm
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm install failed, exiting..."
   exit
fi

# TODO: Confirm if these are needed.
# npm install -g bower
# npm install -g grunt

# TODO: Optionally run bower as part of the build
# bower install --allow-root

# TODO: Confirm if required and add check for error code
# grunt test

npm install
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm install failed, exiting..."
   exit
fi

grunt build
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "grunt build failed, exiting..."
   exit
fi

npm prune --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm prune failed, exiting..."
   exit
fi

# Package for docker if required
if [[ -f Dockerfile ]]; then
    ${GSGEN_JENKINS}/manageDocker.sh -b
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        exit
    fi
fi

# TODO: Package for AWS Lambda if required - not sure yet what to check for as a marker

echo "GIT_COMMIT=$GIT_COMMIT" >> $WORKSPACE/context.properties
echo "SLICE=$SLICE" >> $WORKSPACE/context.properties
