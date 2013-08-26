#!/bin/bash

# BLUEBRIDGE prototype args
# $3 is Summary
# $4 is Severity
# $5 is Node
# $6 is Identifier
# $7 is Serial
# $8 is ServerName

echo "Early Arg3 is >>$3<<" >> nco_bbridge.log

APIHOST="api.boundary.com"

#Define API and ORG information for connection with Boundary
OrgID=""
APIKEY=""

function print_help() {
  echo "./create_event.sh -i ORGID -a APIKEY"
  exit 0
}

function create_event() {

  local LOCATION=`curl -is -X POST -H "Content-Type: application/json" \
  -d '{"fingerprintFields":["@title"], "severity": "ERROR", "source":{ "ref": "netcool", "type": "objectserver"}, "properties":{"nco-summary": "'"$3"'", "nco-node": "'"$4"'", "nco-severity": "'"$5"'", "nco-identifier": "'"$6"'", "nco-serial": "'"$7"'", "nco-osname": "'"$8"'"}, "tags":["tag1","tag2","tag3"], "title":"netcool event id '"$7"'", "message":"'"$3"'" }' -u "$1:" $2  \
        | grep Location \
        | sed 's/Location: //' \
        | sed 's/\(.*\)./\1/'`

  echo $LOCATION
}

if [ ! -z $OrgID ]
  then
    if [ ! -z $APIKEY ]
      then
        URL="https://$APIHOST/$OrgID/events"

        EVENT_LOCATION=`create_event $APIKEY $URL "$1" "$2" "$3" "$4" "$5" "$6"`

        if [ ! -z $EVENT_LOCATION ]
          then
            echo "An event was created at $EVENT_LOCATION"
          else
            echo "No location header received, error creating event!"
            exit 1
        fi
      else
        print_help
      fi
else
  print_help
fi
