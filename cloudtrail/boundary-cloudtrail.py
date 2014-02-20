#!/usr/bin/env python

#Author: Patrick Barker
#Summary: This is a simple python script used to generate Boundary events from AWS CloudTrail records.
#Last update: Aug 22, 2013
#Reason: 


import sys
import time
import pprint
import gzip
import boto
from boto.sqs.message import RawMessage
import json
import urllib2
import base64
import os
import ConfigParser

config = ConfigParser.RawConfigParser()
config.read(os.path.join(os.path.dirname(__file__), 'boundary-cloudtrail.cfg'))

#Boundary Variables
API_URL = config.get('boundary', 'api-url')
ORG_ID = config.get('boundary', 'org-id')
API_KEY = config.get('boundary', 'api-key')

#AWS Variables
AWS_TMP_PATH = config.get('cloudtrail', 'tmp-path')
AWS_ID = config.get('cloudtrail', 'access-key-id')
AWS_KEY = config.get('cloudtrail', 'secret-access-key')
AWS_REGION = config.get('cloudtrail', 'region')
SQS_QUEUE = config.get('cloudtrail', 'sqs-queue-name')


def process_queue():
    conn = boto.sqs.connect_to_region(AWS_REGION, aws_access_key_id=AWS_ID, aws_secret_access_key=AWS_KEY)
    #conn = boto.connect_sqs(AWS_ID, AWS_KEY)
    queue = conn.get_queue(SQS_QUEUE)
    queue.set_message_class(RawMessage)
    mcount = queue.count()
    print "message count >>" + str(mcount) + "<<"

    #for i in range(1):
    for i in range(mcount):
        rs = queue.get_messages()
        message = rs[0]
        json_body = json.loads(message.get_body())
        pprint.pprint(json_body)

        if 's3Bucket' in json_body.keys():
            bname = json.dumps(json_body["s3Bucket"])
            bname = bname.strip('"')

            okpath = json.dumps(json_body["s3ObjectKey"][0])
            okpath = okpath.strip('"')

            filename = dl_file(bname, okpath)
            build_event(filename)

            queue.delete_message(message)
        else:
            print "s3Bucket not found in message, skipping message..."
            time.sleep(1)


def dl_file(bname, okpath):
    print bname + ' ' + okpath

    conn = boto.connect_s3(AWS_ID, AWS_KEY)
    bucket = conn.get_bucket(bname)

    lst = okpath.split('/')
    lst.reverse()
    okname = lst[0]

    key = bucket.get_key(okpath)
    filename = '/'.join([AWS_TMP_PATH, okname])
    key.get_contents_to_filename(filename)

    return filename


def encode_apikey(apikey):
    b64_auth = base64.encodestring(':'.join([apikey, ''])).replace('\n', '')
    return ' '.join(['Basic', b64_auth])


def create_event(event):
    auth_header = encode_apikey(API_KEY)
    # Create event in boundary.

    url = '/'.join([API_URL, ORG_ID, 'events'])

    event_json = json.dumps(event)
    print "event >>" + event_json + "<<"

    req = urllib2.Request(url, event_json, {'Content-type': 'application/json'})
    req.add_header('Authorization', auth_header)

    return urllib2.urlopen(req)


def build_event(filename):
    json_data = gzip.open(filename, 'rb')
    data = json.load(json_data)
    json_data.close()
    os.remove(filename)
    slink = "https://console.aws.amazon.com/ec2/home?region=" + AWS_REGION + "#s=SecurityGroups"
    awslink = "https://console.aws.amazon.com/console"

    count = 0

    for item in data["Records"]:
        userid = item["userIdentity"]
        #rparams = str(item["requestParameters"])
        rp_json = json.dumps(item["requestParameters"])
        rparams = str(pprint.pformat(rp_json))
        #pprint(userid)

        title = "AWS CloudTrail - " + item["eventName"]
        action = item["eventName"]

        severity = "INFO"
        if "Describe" not in action:
            severity = "WARN"
        if "Revoke" in action:
            severity = "CRITICAL"
        if "Authorize" in action:
            severity = "ERROR"

        region = item["awsRegion"]
        source = item["sourceIPAddress"]
        sender = "AWS CloudTrail"
        status = "OK"
        principal = userid["principalId"]
        utype = userid["type"]
        arn = userid["arn"]
        account = userid["accountId"]
        eventtime = item["eventTime"]

        agent = "NotIAMAccount"
        if "userAgent" in item:
            agent = item["userAgent"]

            if len(agent) > 20: 
                lst = agent.split('/')
                agent = lst[0]
 
        username = "sampleIAMuser"
        if "userName" in userid:
            username = userid["userName"]

        groupname = ""
        if "ipPermissions" in rparams:
            #groupname = json.dumps(rparams["ipPermissions"][0]["groupName"])
            groupname = json.dumps(rparams[0])

        print "groupname >>" + groupname + "<<"
        message = item["eventName"] + " was executed on " \
            + item["eventSource"] + " from " \
            + source + " through " \
            + agent + " in " \
            + region + " by " \
            + username
     
        if "Security" in action:
            event = {
                'source': {"type": "host", "ref": source},
                'sender': {"type": sender, "ref": sender},
                'properties': {
                    "sender": sender, "source": source, "action": action,
                    "agent": agent, "accountid": account, "username": username,
                    "eventtime": str(eventtime), "AWS Link": [{"href": slink}]
                },
                'title': title,
                'createdAt': eventtime,
                'message': message,
                'severity': severity,
                'status': status,
                'tags': [source, sender, severity, action, region, agent, account, username],
                'fingerprintFields': ['source', 'sender', 'action', 'username', 'eventtime']
            }
        else:
            event = {
                'source': {"type": "host", "ref": source},
                'sender': {"type": sender, "ref": sender},
                'properties': {
                    "sender": sender, "source": source, "action": action,
                    "agent": agent, "accountid": account, "username": username,
                    "AWS Link": [{"href": awslink}]
                },
                'title': title,
                'createdAt': eventtime,
                'message': message,
                'severity': severity,
                'status': status,
                'tags': [source, sender, severity, action, region, agent, account, username],
                'fingerprintFields': ['source', 'sender', 'action', 'username']
            }

        #pprint(event)
        create_event(event)

        #for throttling purposes
        count += 1

        if count / 2 == 1:
            time.sleep(1) 
            count = 0

    print "Processed AWS CloudTrail payload >>" + filename + "<<"


def main():
    if len(sys.argv) > 1:
        build_event(str(sys.argv[1]))
    else:
        process_queue()

if __name__ == "__main__":
    main()
