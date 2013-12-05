#!/usr/bin/env python
"""Boundary Events API Client for Python.

See also: https://app.boundary.com/docs/events_api
"""

# Copyright 2011-2013, Boundary Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

__author__ = 'Greg Albrecht <gba@splunk.com>, C. Scott Andreas <s@boundary.com>, and Clint Sharp'
__copyright__ = 'Copyright 2013 Boundary and Splunk, Inc.'
__license__ = 'Apache License 2.0'


import base64
import ConfigParser
try:
    import json
except ImportError:
    import simplejson as json  # pylint: disable=F0401
import os
import traceback
import urllib2
import socket
import time

API_URL = 'https://api.boundary.com'


class BoundaryEvents(object):
    """Boundary Events API Client"""

    def __init__(self, organization_id, api_key):
        self.url = '/'.join([API_URL, organization_id, 'events'])

        # 'Python urllib2 Basic Auth Problem': http://bit.ly/KZDZNk
        b64_auth = base64.encodestring(
            ':'.join([api_key, ''])
        ).replace('\n', '')

        self.auth_header = ' '.join(['Basic', b64_auth])

    def create_event(self, event):
        """Creates an Event in Boundary.

        @param event: Event Params per
            https://app.boundary.com/docs/events_api
        @type event: dict

        @return: Response from Boundary.
        @rtype: dict
        """
        event_json = json.dumps(event)

        req = urllib2.Request(
            self.url, event_json, {'Content-type': 'application/json'}
        )

        req.add_header('Content-Type', 'application/json')
        req.add_header('Authorization', self.auth_header)

        # TODO(gba) Add error checking, since there basically isn't any.
        response = urllib2.urlopen(req)
        contents = response.read()
        response.close()

        return contents


def get_api_credentials(config_file):
    """Extracts Boundary API key and Organization ID from Splunk Config.

    @return: API key, Organization ID.
    @rtype: tuple
    """
    api_credentials = ()
    if config_file is not None and os.path.exists(config_file):
        config = ConfigParser.ConfigParser()
        config.read(config_file)
        api_credentials = (
            config.get('boundary', 'api_key'),
            config.get('boundary', 'org_id')
        )
    return api_credentials


def search_command(apiclient):
    """Invokes Boundary Annotations as a Search Command."""
    import splunk
    import splunk.Intersplunk

    try:
        results, _, _ = splunk.Intersplunk.getOrganizedResults()
        for result in results:
            createdAt = time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime( float(result['_time']) ))
            title = result['_raw']
            message = result['_raw']
            if len(title) > 254:
                    title = title[:254]
                    message = message[:200]
            event = {
                 'title' : title,
                 'message' : 'Results of a Splunk Search command:' + message,
                 'tags' : ["Splunk","search"],
                 'status' : "OK",
                 'severity' : "INFO",
                 'source' : {
                        'ref' : result['host'],
                        'type' : "instance"
                 },
                 'sender' : {
                        'ref' : "Splunk",
                        'type' : "Application"
                 },
                 'properties' : {
                        'eventKey' : "Splunk-search",
                        'sender' : "Splunk",
                 },
                 'fingerprintFields' : [ "eventKey","sender"],
                 'createdAt' : createdAt
	    }
            apiclient.create_event(event)
    # TODO(gba) Catch less general exception.
    except Exception:
        stack = traceback.format_exc()
        results = splunk.Intersplunk.generateErrorResults(
            "Error : Traceback: " + str(stack)
        )
    finally:
        splunk.Intersplunk.outputResults(results)


def alert_command(apiclient):
    """Invokes Boundary Events as a Saved-Search Alert Command."""
    message = 'Splunk Alert on ' + socket.gethostbyname(socket.gethostname()) + ' @ os.environ.get(\'SPLUNK_ARG_8\') - ' + os.environ.get('SPLUNK_ARG_6')
    if len(message) > 255:
            message = message[:254]
    event = {
                'title': os.environ.get('SPLUNK_ARG_4'),
                 'message' : message,
                 'tags' : ["Splunk","alert"],
                 'status': "OPEN",
                 'severity': "ERROR",
                 'source': {
                        'ref': socket.gethostbyname(socket.gethostname()),
                        'type':"instance"
                 },
                 'sender': {
                        'ref': "Splunk",
                        'type':"Application"
                 },
                 'properties': {
                        'eventKey': "Splunk-alert",
                        'source': socket.gethostbyname(socket.gethostname()),
                        'sender': "Splunk",
                 },
                 'fingerprintFields': [ "eventKey","source","sender"]
    }
    return apiclient.create_event(event)


def get_config_file():
    """Gets Boundary Config File location.

    @return: Path to Boundary Config File.
    @rtype: str
    """
    config_file = 'boundary.conf'
    splunk_home = os.environ.get('SPLUNK_HOME')

    if splunk_home is not None and os.path.exists(splunk_home):
        _config_file = os.path.join(
            splunk_home, 'etc', 'apps', 'boundary', 'local',
            'boundary.conf')
        if os.path.exists(_config_file):
            config_file = _config_file

    return config_file


def setup_apiclient():
    """Sets up Boundary API Instance."""
    api_key, organization_id = get_api_credentials(get_config_file())
    return BoundaryEvents(organization_id, api_key)


def main():
    """Differentiates alert invocation from search invocation."""
    if 'SPLUNK_ARG_1' in os.environ:
        alert_command(setup_apiclient())
    else:
        search_command(setup_apiclient())


if __name__ == '__main__':
    main()
