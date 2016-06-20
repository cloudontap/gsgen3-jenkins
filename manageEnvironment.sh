#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Generate the deployment template for the required slice
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"

# Process the slices
for LEVEL in segment solution; do
    SLICES="${LEVEL^^}_SLICES"
    for SLICE in ${!SLICES}; do
    
    	# Generate the template if required
        cd ${WORKSPACE}/${OAID}/config/${PROJECT}/solutions/${SEGMENT}
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
        cd ${WORKSPACE}/${OAID}/infrastructure/${PROJECT}

        # Ensure git knows who we are
        git config user.name  "${GIT_USER}"
        git config user.email "${GIT_EMAIL}"

        # Record changes
        git add *
        git commit -m "Stack changes as a result of applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${SEGMENT} segment"
        git push origin master
	    RESULT=$?
        if [[ "${RESULT}" -ne 0 ]]; then
            echo "Unable to save the changes resulting from applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${SEGMENT} segment"
            exit
        fi
    done
done

# Check credentials if required
if [[ "${CHECK_CREDENTIALS}" == "true" ]]; then
    cd ${WORKSPACE}/${OAID}
    ${BIN_DIR}/initProjectCredentials.sh -a ${OAID} -p ${PROJECT} -c ${SEGMENT}

    # Update the infrastructure repo to capture any credential changes
    cd ${WORKSPACE}/${OAID}/infrastructure/${PROJECT}

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
    cd ${WORKSPACE}/${OAID}
    ${BIN_DIR}/syncAccountBuckets.sh -a ${OAID}
fi



