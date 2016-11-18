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

# Change to the app directory
cd app

# Install required npm packages
npm install --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm install failed"
   exit
fi

# Build meteor but don't tar it
meteor build ../dist --directory
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nmeteor build failed"
   exit
fi
cd ..

# Install the required node modules
(cd dist/bundle/programs/server && npm install --production)
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nInstallation of app node modules failed"
   exit
fi

# Sanity check on final size of build
MAX_METEOR_BUILD_SIZE=${MAX_METEOR_BUILD_SIZE:-100}
if [[ $(du -s -m ./dist | cut -f 1) -gt ${MAX_METEOR_BUILD_SIZE} ]]; then
    RESULT=1
    echo -e "\nBuild size exceeds ${MAX_METEOR_BUILD_SIZE}M"
    exit
fi


# Package for docker if required
if [[ -f Dockerfile ]]; then
    ${GSGEN_JENKINS}/manageDocker.sh -b -s ${SLICE} -g ${GIT_COMMIT}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        exit
    fi
fi

echo "GIT_COMMIT=$GIT_COMMIT" >> $WORKSPACE/chain.properties
echo "SLICE=$SLICE" >> $WORKSPACE/chain.properties
