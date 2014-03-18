#!/usr/bin/env python

'''

Created on Mar 5, 2014

@author: davidg@boundary.com

'''

import requests
import json
import platform
from datetime import datetime

def main():
    """
    Example Python function that shows to create an event using the Boundary Event API
    """
    #
    # Your API key and Organization ID uniquely identify you and your organization,
    # allowing secure access to Boundary API services.
    #
    apiKey = '<Your API Key Here>'
    organizationID = '<Your Organization ID Here>'

    #
    # Boundary's API event path is of the form:
    #
    # https://<API HOST>/<ORGANIZATION ID>/events
    #
    url = 'https://api.boundary.com/{0}/events'.format(organizationID)

    #
    # Create a dictionary that defines the event
    #
    # Required Fields:
    #    source
    #    fingerprintFields NOTE: The fields of the event used to calculate the uniqueness of the event
    #    title
    event = {"title": 'Boundary API Event Example',
             "tags": ["example"],
             "fingerprintFields": ["@message"],
             "source": { "ref": platform.node(),"type": "host"},
             "message": 'test @ ' + str(datetime.now())
            }
    #
    # Add HTTP request header to indicate that the body of the request is JSON
    #
    headers = {'Content-Type': 'application/json'}

    #
    # POST the event to the Boundary API host
    #
    # url - Boundary Event API uri as created above
    # data - JSON payload transformed from event dictionary as created above
    # header - HTTP request header identifying the body of the request
    # auth - HTTP Authorization header composed of user:password, where user is the API key and password
    #        is empty
    r = requests.post(url,data=json.dumps(event), headers=headers,auth=(apiKey,''))
   
    print('HTTP Status Code: ' + str(r.status_code))
    
    #
    # Successful creation of an event returns HTTP Status Code of 201
    #
    if r.status_code == 201:
        #
        # HTTP Reponse header 'Location' has the URL for the newly created event
        #
        location = str(r.headers['Location'])

        #
        # Extract the event ID from the URI
        #
        eventID = location.rsplit('/',1)[-1]
        print('eventId: ' + str(eventID))    

if __name__ == '__main__':
    main()
