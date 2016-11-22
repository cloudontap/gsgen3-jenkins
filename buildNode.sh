#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z "${SLICE_LIST}" ]]; then
    if [ -e slices.ref ]; then
        SLICE_LIST=`cat slices.ref`
    else
        if [ -e slice.ref ]; then
            SLICE_LIST=`cat slice.ref`
        fi
    fi
fi

SLICE_ARRAY=(${SLICE_LIST})

# Perform checks for Docker packaging
if [[ -f Dockerfile ]]; then
    ${AUTOMATION_DIR}/manageDocker.sh -v -s ${SLICE_ARRAY[0]} -g ${GIT_COMMIT}
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
   echo -e "\nnpm install failed"
   exit
fi

# Run bower as part of the build if required
if [[ -f bower.json ]]; then
    bower install --allow-root
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\nbower install failed"
       exit
    fi
fi

# Grunt based build
if [[ -f gruntfile.js ]]; then
    grunt build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\ngrunt build failed"
       exit
    fi
fi

# Gulp based build
if [[ -f gulpfile.js ]]; then
    gulp build
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo -e "\ngulp build failed"
       exit
    fi
fi

# Clean up
npm prune --production
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\nnpm prune failed"
   exit
fi

# Package for docker if required
if [[ -f Dockerfile ]]; then
    ${AUTOMATION_DIR}/manageDocker.sh -b -s ${SLICE_ARRAY[0]} -g ${GIT_COMMIT}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        exit
    fi
fi

# TODO: Package for AWS Lambda if required - not sure yet what to check for as a marker

echo "GIT_COMMIT=$GIT_COMMIT" >> $WORKSPACE/chain.properties
echo "SLICES=${SLICE_LIST}" >> $WORKSPACE/chain.properties
