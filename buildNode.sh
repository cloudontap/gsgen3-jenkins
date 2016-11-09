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

# TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker

npm install --unsafe-perm
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm install failed, exiting..."
   exit
fi

# Run bower as part of the build if required
if [[ -f bower.json ]]; then
    bower install --allow-root
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo "bower install failed, exiting..."
       exit
    fi
fi

# Grunt based build
if [[ -f gruntfile.js ]]; then
    grunt build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo "grunt build failed, exiting..."
       exit
    fi
fi

# Gulp based build
if [[ -f gulpfile.js ]]; then
    gulp build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo "gulp build failed, exiting..."
       exit
    fi
fi

# Clean up
npm prune --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm prune failed, exiting..."
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

# TODO: Package for AWS Lambda if required - not sure yet what to check for as a marker

echo "GIT_COMMIT=$GIT_COMMIT" >> $WORKSPACE/chain.properties
echo "SLICE=$SLICE" >> $WORKSPACE/chain.properties
