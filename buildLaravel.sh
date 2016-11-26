#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

. ${AUTOMATION_DIR}/performPreBuildChecks.sh

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

. ${AUTOMATION_DIR}/createImages.sh

# All good
RESULT=0
