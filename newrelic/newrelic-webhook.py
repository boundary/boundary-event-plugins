#!/usr/bin/env python

"""
Standalone python web server to recieve webhook calls from New Relic and forward them to Boundary
"""

import BaseHTTPServer
import json
import logging
import urllib2
import os
from ConfigParser import SafeConfigParser
from base64 import b64encode

LOG = logging.getLogger('newrelic-webhook')

HOSTNAME = '0.0.0.0'
PORT     = 8080

BOUNDARY_ORG_ID = None
BOUNDARY_AUTHORIZATION_KEY = None

API_ENDPOINT = 'https://api.boundary.com'

SEVERITY_MAP = {
	'critical': 'CRITICAL',
	'caution': 'WARN',
	'downtime': 'CRITICAL',
}

def load_config():
	global BOUNDARY_AUTHORIZATION_KEY, BOUNDARY_ORG_ID, HOSTNAME, PORT
	cfg_file = os.path.join(os.path.dirname(__file__), "newrelic-webhook.cfg")
	if os.path.isfile(cfg_file):
		config = SafeConfigParser()
		config.read(cfg_file)
		
		BOUNDARY_ORG_ID = config.get("boundary", "organization-id").strip()
		BOUNDARY_AUTHORIZATION_KEY = config.get("boundary", "api-key").strip()
		
		HOSTNAME = config.get("newrelic", "host").strip()
		PORT = int(config.get("newrelic","port").strip())

class WebhookHandler(BaseHTTPServer.BaseHTTPRequestHandler):
	def do_POST(self):
		""" Response to POST request """
		self.post_data = self.rfile.read(int(self.headers['Content-Length']))
		self.send_response(202)
		self.end_headers()

		""" Process JSON from request """
		""" Hack because NR sends invalid JSON """
		s = self.post_data.split(': ',1)
		nr_event_type = s[0]
		nr_event_json = s[1]
		nr_event = json.loads(nr_event_json)

		""" Map new relic object to Boundary event """
		b_event = { 
			'title': nr_event_type,
			'fingerprintFields': ['alert_url',],
			'source': { 'ref': nr_event['application_name'], 'type': 'application'},
			'sender': { 'ref': 'New Relic', 'type': 'Adapter'},
			'createdAt': nr_event['created_at'],
		}

		if nr_event_type == 'alert':
			b_event['status'] = 'OPEN'

		for field in ['long_description','message','short_description','description']:
			if (field in nr_event):
				b_event['message'] = nr_event[field]
				break

		if ('severity' in nr_event and nr_event['severity'] in SEVERITY_MAP):
			b_event['severity'] = SEVERITY_MAP[nr_event['severity']]

		""" Put everything else in properties """
		b_event['properties'] = nr_event

		b_event_json = json.dumps(b_event)
		req = urllib2.Request("%s/%s/events" % (API_ENDPOINT, BOUNDARY_ORG_ID), b_event_json, {
			'Content-Type': 'application/json',
			'Authorization': 'Basic %s' % b64encode(BOUNDARY_AUTHORIZATION_KEY),
		})
		resp = urllib2.urlopen(req)

if __name__ == '__main__':
	logging.basicConfig()
	logging.root.setLevel(logging.INFO)
	for handler in logging.root.handlers:
		handler.level = logging.INFO
	load_config()
	server_class = BaseHTTPServer.HTTPServer
	httpd = server_class((HOSTNAME, PORT), WebhookHandler)

	try:
		httpd.serve_forever()
	except KeyboardInterrupt:
		pass
	httpd.server_close()
