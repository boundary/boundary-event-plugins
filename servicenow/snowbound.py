#!/usr/bin/env python

#SNOWBOUND - This is a python based "plug-in" that can be used to generate tickets in ServiceNow from Boundary events.
#Author: Patrick Barker
#Last update: Sep 24, 2013
#Reason: Update the script to select a single event from Boundary and create a ticket in ServiceNow for it. 


import sys
from random import choice
from pprint import pprint
import random
import time
import ConfigParser
try:
    import json
except ImportError:
    import simplejson as json
try:
    import urllib2
    import base64
    import os
    from optparse import OptionParser
    import ConfigParser
    import datetime
except ImportError, err:
    sys.stderr.write("ERROR: Couldn't load module. %s\n" % err)
    sys.exit(-1)

__all__ = [ 'main', ]

config = ConfigParser.RawConfigParser()
config.read('snowbound.cfg')

# global variables
BN_URL=config.get('boundary', 'main-url')
API_URL=config.get('boundary', 'api-url')
API_KEY=config.get('boundary', 'api-key')
ORG_ID=config.get('boundary', 'org-id')
E_QUERY=config.get('boundary', 'event-query')

SN_URL=config.get('servicenow', 'url')
SN_CRD=':'.join([config.get('servicenow', 'user'), config.get('servicenow', 'pass')])

DT_FORMAT = '%Y-%m-%dT%H:%M:00.000+02:00'


def encode_bn_auth():
    b64_auth = base64.encodestring( ':'.join([API_KEY, ''])).replace('\n', '')
    return ' '.join(['Basic', b64_auth])

def encode_sn_auth():
    b64_auth = base64.encodestring( SN_CRD ).replace('\n', '')
    return ' '.join(['Basic', b64_auth])

def get_tickets(auth_header):
    url = '/'.join([SN_URL, 'incident.do?JSON&sysparm_action=getRecords&sysparm_query=active=true'])

    req = urllib2.Request(url)

    req.add_header('Authorization',auth_header)

    response = urllib2.urlopen(req)

    tickets = json.load(response)

    for ticket in tickets ["records"]:
        pprint(ticket)

def get_events(auth_header):
    url = '/'.join([API_URL, ORG_ID, E_QUERY])

    print "query url >>>" + url + "<<<"

    req = urllib2.Request(url)

    req.add_header('Authorization',auth_header)

    response = urllib2.urlopen(req)

    events = json.load(response)

    return events

def update_event(auth_header, event, ticketid):
    #connect to boundary
    url = '/'.join([API_URL, ORG_ID, 'events'])

    #set time
    event["createdAt"] = event["lastUpdatedAt"]

    #update properties
    tlink = SN_URL + "/incident.do?sysparm_query=number%3D" + ticketid
    props = event["properties"]
    plink = {'ticket link' : [{"href":tlink}]}
    props.update (plink)
    event["properties"] = props

    #update tags
    tags = []

    if len(event["tags"]) > 0:
        tags = event["tags"]

    tags.append ("ticketed")
    tags.append (str(ticketid))
    event["tags"] = tags

    #encode event record
    event_json = json.dumps(event)

    #transmit update request
    req = urllib2.Request(url, event_json, {'Content-type': 'application/json'})
    req.add_header('Authorization', auth_header)
    response = urllib2.urlopen(req)

    print response.read()

def build_ticket(event):
    equery='events?search=id%3A' + str(event["id"])
    elink='/'.join([BN_URL, ORG_ID, equery])

    ticket = {
        'sysparm_action':"insert",
        'short_description':event["title"],
        'priority':"1",
        'opened_by':"Boundary",
        'work_notes': '\n' \
        + '[code]<a href="' + elink + '"> Boundary Event Link </a>[/code]' \
        + '\n' + 'event id: ' + str(event["id"]) \
        + '\n' + 'event message: ' + event["message"] \
        + '\n' + 'event severity: ' + event["severity"] \
        + '\n' + 'event status: ' + event["status"] \
        + '\n' + 'event sender: ' + str(event["sender"]["ref"]) \
        + '\n' + 'event first seen at: ' + event["firstSeenAt"] \
        + '\n' + 'event last seen at: ' + event["lastSeenAt"] 
    }

    return ticket

def generate_tickets(bn_auth_header, sn_auth_header):
    #Use get_events to grab an event and use its fields to create the ticket
    events = get_events(bn_auth_header)

    for event in events["results"]:
        ticket = build_ticket(event) 

        ticketid = post_ticket(ticket,sn_auth_header)

        print "ticket number >>>" + ticketid + "<<<" + " event id >>>" + str(event["id"]) + "<<<"

        update_event(bn_auth_header, event, ticketid)

def post_ticket(ticket,auth_header):
    url = '/'.join([SN_URL,'incident.do?JSON'])

    ticket_json = json.dumps(ticket)

    req = urllib2.Request( url, ticket_json, {'Content-type': 'application/json'})

    req.add_header('Authorization', auth_header)
    response = urllib2.urlopen(req)
    ticket = json.load (response)

    return ticket["records"][0]["number"]

def main():
    bn_auth_header = encode_bn_auth()
    #get_events(bn_auth_header)

    sn_auth_header = encode_sn_auth()
    #get_tickets(sn_auth_header)

    generate_tickets(bn_auth_header, sn_auth_header)

if __name__ == "__main__":
    main()
