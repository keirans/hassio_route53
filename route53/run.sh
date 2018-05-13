#!/bin/bash
# Hass.io Amazon Route53 Dynamic DNS plugin.
# Keiran Sweet <keiran@gmail.com>
#
# This plugin allows you to update a record in Route53 to point to your discovered IP
# address. By default, we determine the IP address from ipify in the config.json,
# however you can set this to any HTTP/HTTPS endpoint of your choice if required.
# 
# For full configuration information, please see the README.md
# 

# Source in some helper functions that make handling JSON easier in bash
source /usr/lib/hassio-addons/base.sh

#
# Pull in the required values from the config.json file
# 
export AWS_SECRET_ACCESS_KEY=$(hass.config.get 'AWS_SECRET_ACCESS_KEY')
export AWS_DEFAULT_REGION=$(hass.config.get 'AWS_REGION')
export AWS_REGION=$(hass.config.get 'AWS_REGION')
export AWS_ACCESS_KEY_ID=$(hass.config.get 'AWS_ACCESS_KEY_ID')
export RECORDNAME=$(hass.config.get 'RECORDNAME')
export TIMEOUT=$(hass.config.get 'TIMEOUT')  
export ZONEID=$(hass.config.get 'ZONEID')
export IPURL=$(hass.config.get 'IPURL')
export DEBUG=$(hass.config.get 'DEBUG')

# Functions used for the addon.

# Debugging message wrapper used to echo values only if debug is set to true
function debug_message {
    if [ $DEBUG == 'true' ]; then
      echo "$(date) DEBUG : $1"
    fi
}

# Create / Update the Record in Route53 if/when required
# Indentation is a little off because bash's heredoc support doesnt like indentation..
#
function update_record {
    echo "$(date) INFO : Updating / Creating the A record for ${RECORDNAME} in Zone ${ZONEID}"

    rm -f /tmp/createjson.tmp

cat << ENDOFCREATEJSON > /tmp/createjson.tmp
    {
        "Comment": "Home Assistant ",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${RECORDNAME}",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {
                            "Value": "${IPADDRESS}"
                        }
                    ]
                }
            }
        ]
    }
ENDOFCREATEJSON

    aws route53 change-resource-record-sets --hosted-zone-id ${ZONEID} --change-batch file:///tmp/createjson.tmp

}

# Evaluate the current state of the record, and then update if required.
function evaluate_record {

    export RECORDADDRESS=$(aws route53  test-dns-answer --hosted-zone-id ${ZONEID} --record-type A --record-name ${RECORDNAME} | jq '.RecordData[0]' | sed -e 's/"//g')

    if [ $IPADDRESS == $RECORDADDRESS ]; then
        debug_message "The Addresses match - nothing to do ($IPADDRESS is the same as $RECORDADDRESS)"
    else
        echo "$(date) INFO : The Addresses don't match ($IPADDRESS is not the same as $RECORDADDRESS) - Updating record"
        update_record
    fi

}


#
# Main Program body - This is where the action happens
#

# If debug is true, dump the runtime data first.
debug_message "-------------------------------------------"
debug_message "Dumping Debugging data"
debug_message "Got AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}"
debug_message "Got AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}"
debug_message "Got AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
debug_message "Got TIMEOUT: ${TIMEOUT}"
debug_message "Got IPURL: ${IPURL}"
debug_message "Got TIMEOUT: ${TIMEOUT}"
debug_message "Got RECORDNAME: ${RECORDNAME}"
debug_message "Got ZONEID: ${ZONEID}"
debug_message "-------------------------------------------"


while true
do

    debug_message "Executing main program body"
    export IPADDRESS=$(curl -s ${IPURL})
    export RESPONSECODE=$(aws route53  test-dns-answer --hosted-zone-id ${ZONEID} --record-type A --record-name ${RECORDNAME} | jq '.ResponseCode')

    debug_message "Got ${RESPONSECODE}"

    case $RESPONSECODE in

        '"NXDOMAIN"')
            echo "$(date) INFO : Got NXDOMAIN (${RESPONSECODE}) - Creating new A Record"
            update_record
        ;;

        '"NOERROR"')
            debug_message "Got NOERROR (${RESPONSECODE}) - Continue to ensure IP address is correct in record"
            evaluate_record
        ;;

        *)
            echo "$(date) INFO : Got ${RESPONSECODE} that was not NXDOMAIN or NOERROR - CANNOT CONTINUE"
            exit 1
        ;;

    esac
    debug_message "Sleeping for ${TIMEOUT} seconds"
    sleep $TIMEOUT
done
