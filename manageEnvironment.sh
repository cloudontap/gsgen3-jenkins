#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
JENKINS_DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Generate the deployment template for the required slice
BIN_DIR="${WORKSPACE}/${AID}/config/bin"

# Process the slices
for LEVEL in segment solution; do
    SLICES="${LEVEL^^}_SLICES"
    for SLICE in ${!SLICES}; do
    
    	# Generate the template if required
        cd ${WORKSPACE}/${AID}/config/${PRODUCT}/solutions/${SEGMENT}
        case ${MODE} in
            create|update)
   	            ${BIN_DIR}/create${LEVEL^}Template.sh -s ${SLICE}
                RESULT=$?
                if [[ "${RESULT}" -ne 0 ]]; then
            	    echo "Generation of the ${LEVEL} level template for the ${SLICE} slice of the ${SEGMENT} segment failed"
                    exit
                fi
		    ;;
        esac
        
        # Manage the stack
        ${BIN_DIR}/${MODE}Stack.sh -t ${LEVEL} -s ${SLICE}
	    RESULT=$?
        if [[ "${RESULT}" -ne 0 ]]; then
            echo "Applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${SEGMENT} segment failed"
            exit
        fi
        
		# Update the infrastructure repo to capture any stack changes
        ${JENKINS_DIR}/manageRepo.sh -p \
            -d ${WORKSPACE}/${AID}/infrastructure/${PRODUCT} \
            -n infrastructure \
            -m "Stack changes as a result of applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${SEGMENT} segment"
            
	    RESULT=$?
        if [[ "${RESULT}" -ne 0 ]]; then
            echo "Unable to save the changes resulting from applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${SEGMENT} segment"
            exit
        fi
    done
done

# Check credentials if required
if [[ "${CHECK_CREDENTIALS}" == "true" ]]; then
    cd ${WORKSPACE}/${AID}
    SEGMENT_OPTION=""
    if [[ -n "${SEGMENT}" ]]; then
       SEGMENT_OPTION="-s ${SEGMENT}"
    fi 
    ${BIN_DIR}/initProductCredentials.sh -a ${AID} -p ${PRODUCT} ${SEGMENT_OPTION}

    # Update the infrastructure repo to capture any credential changes
    cd ${WORKSPACE}/${AID}/infrastructure/${PRODUCT}

	# Ensure git knows who we are
    git config user.name  "${GIT_USER}"
    git config user.email "${GIT_EMAIL}"
 
    # Record changes
    git add *
    git commit -m "Credential updates for the ${SEGMENT} segment"
    git push origin master
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Unable to save the credential updates for the ${SEGMENT} segment"
        exit
    fi
fi

# Update the code and credentials buckets if required
if [[ "${SYNC_BUCKETS}" == "true" ]]; then
    cd ${WORKSPACE}/${AID}
    ${BIN_DIR}/syncAccountBuckets.sh -a ${AID}
fi



