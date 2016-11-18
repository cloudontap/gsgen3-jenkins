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

cd laravel/

/usr/local/bin/composer install --prefer-source --no-interaction
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\ncomposer install fails with the exit code $RESULT"
   exit
fi

/usr/local/bin/composer update
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\ncomposer update fails with the exit code $RESULT"
   exit
fi

cd ../

# Package for docker if required
if [[ -f Dockerfile ]]; then
    ${GSGEN_JENKINS}/manageDocker.sh -b -s ${SLICE}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        exit
    fi
fi

echo "PRODUCT=$PRODUCT" >> $WORKSPACE/context.properties
echo "SLICE=$SLICE" >> $WORKSPACE/context.properties
