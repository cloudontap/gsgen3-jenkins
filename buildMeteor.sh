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
    ${GSGEN_JENKINS}/manageDocker.sh -v -s ${SLICE}
    RESULT=$?
    if [[ "${RESULT}" -eq 0 ]]; then
        RESULT=1
        exit
    fi
fi

# Install required npm packages
npm install --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm install failed, exiting..."
   exit
fi

# Build meteor 
meteor build dist 
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "meteor build failed, exiting..."
   exit
fi

# Install the required node modules
(cd dist/bundle/programs/server && npm install)
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "Installation of app node modules failed, exiting..."
   exit
fi

# Package for docker if required
if [[ -f Dockerfile ]]; then
    ${GSGEN_JENKINS}/manageDocker.sh -b -s ${SLICE}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        exit
    fi
fi

echo "GIT_COMMIT=$GIT_COMMIT" >> $WORKSPACE/context.properties
echo "SLICE=$SLICE" >> $WORKSPACE/context.properties
