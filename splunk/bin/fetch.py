#!/usr/bin/env python

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


import os
import csv
import time
import json
import base64
import urllib2
import logging
import ConfigParser

class Boundary():
    def __init__(self, config_file):
        config = ConfigParser.ConfigParser()
        config.readfp(open(config_file))
        logging.basicConfig(level=logging.INFO)

        # API config
        api_key = config.get('boundary', 'api_key')
        self.org_id = config.get('boundary', 'org_id')
        self.api_base = config.get('boundary', 'api_base')
        self.auth = "Basic %s" % base64.encodestring('%s:' % (api_key))[:-1]

        # Output config
        self.app_map_output = config.get('boundary', 'app_map_output')
        self.host_to_app_map_output = config.get('boundary', 'host_to_app_map_output')
        self.meter_info_output = config.get('boundary', 'meter_info_output')
        self.app_to_app_output = config.get('boundary', 'app_to_app_output')

        if 'SPLUNK_HOME' in os.environ:
            self.app_map_output = self.app_map_output.replace('$SPLUNK_HOME', os.environ['SPLUNK_HOME'])
            self.host_to_app_map_output = self.host_to_app_map_output.replace('$SPLUNK_HOME', os.environ['SPLUNK_HOME'])
            self.meter_info_output = self.meter_info_output.replace('$SPLUNK_HOME', os.environ['SPLUNK_HOME'])
            self.app_to_app_output = self.app_to_app_output.replace('$SPLUNK_HOME', os.environ['SPLUNK_HOME'])
        
    # Fetch data from an API endpoint with auth and return the parsed JSON.
    def get(self, url):
        logging.info("Fetching %s" % url)
        req = urllib2.Request(self.api_base + url)
        req.add_header("Authorization", self.auth)
        return json.loads(urllib2.urlopen(req).read())

    # Load data from the Boundary Meters API
    def get_meters(self):
        return self.get("/%s/meters" % self.org_id)

    # Load data from the Boundary Applications API
    def get_applications(self):
        return self.get("/%s/applications" % self.org_id)
    
    def get_convo_graph(self):
        return self.get("/%s/query_state/conversation_graph" % self.org_id)

    # Builds a map of hosts => apps on them.
    def build_host_to_app_map(self, apps, meter_info):
        hosts = {}

        for app in apps:
            app_nodes = app['flowProfile']['filter'].get('meters')
            saved_search = app['flowProfile']['filter'].get('saved_search')
            named_app_nodes = []

            if (app_nodes):
                named_app_nodes = [meter_info[node] for node in app_nodes]
            
            if (saved_search):
                entities = self.get("/%s/searches/%s/results?rows=100" % (self.org_id, saved_search))
                if (entities.get("entities")):
                    for entity in entities.get("entities"):
                        named_app_nodes.append(meter_info[int(entity.get("body").get("obs_domain_id"))])
                logging.debug("Entities for %s: %s", (saved_search, repr(entities)))

            for host in named_app_nodes:
                host_no_domain = host.split('.')[0] + '*'
                host = host + '*'
                apps_for_host = hosts.get(host, [])
                apps_for_host.append(app['name'])
                hosts[host] = apps_for_host
                hosts[host_no_domain] = apps_for_host

        return hosts


    # Materalize a list of applications into the list of servers hosting them.
    def build_app_map(self, apps, meter_info):
        app_map = {}

        for app in apps:
            app_nodes = app['flowProfile']['filter'].get('meters')
            saved_search = app['flowProfile']['filter'].get('saved_search')
            named_app_nodes = []

            if (app_nodes):
                named_app_nodes = [meter_info[node] for node in app_nodes]
            
            if (saved_search):
                entities = self.get("/%s/searches/%s/results?rows=100" % (self.org_id, saved_search))
                if (entities.get("entities")):
                    for entity in entities.get("entities"):
                        named_app_nodes.append(meter_info[int(entity.get("body").get("obs_domain_id"))])
                logging.debug("Entities for %s: %s", (saved_search, repr(entities)))
                
            app_map[app['name']] = {'nodes': named_app_nodes, 'id': app['flowProfile']['id']}

        return app_map

    # Write meter info to a CSV file
    def write_meter_info(self, meter_info):
        logging.info("Writing meter info to %s" % self.meter_info_output)
        c = csv.writer(open(self.meter_info_output, 'wb'))
        c.writerow(['host', 'obs_dom_id', 'meter_id', 'export_ip', 'os', 'tags'])

        for m in meter_info:
            c.writerow([m['name']+'*', m['obs_domain_id'], m['id'], m.get('export_address'), \
                m.get('os_distribution_name'), ','.join(m['tags'])])
            c.writerow([m['name'].split('.')[0]+'*', m['obs_domain_id'], m['id'], m.get('export_address'), \
                m.get('os_distribution_name'), ','.join(m['tags'])])

    # Write the app map to a CSV file
    def write_app_map(self, app_map):
        logging.info("Writing app topology to %s" % self.app_map_output)
        c = csv.writer(open(self.app_map_output, 'wb'))
        c.writerow(['app_name', 'conversation_id', 'hosts'])

        for app_name, info_dict in app_map.iteritems():
            c.writerow([app_name, info_dict.get('id'), ','.join(info_dict.get('nodes'))])

    # Write the host to app map to a CSV file
    def write_host_to_app_map(self, app_map):
        logging.info("Writing host to app topology to %s" % self.host_to_app_map_output)
        c = csv.writer(open(self.host_to_app_map_output, 'wb'))
        c.writerow(['host', 'app_names'])

        for hostname, app_list in app_map.iteritems():
            c.writerow([hostname, ','.join(app_list)])


    def write_app_to_app(self, apps, convo_graph):
        logging.info("Writing app-to-app data to %s" % self.app_to_app_output)
        c = csv.writer(open(self.app_to_app_output, 'wb'))
        c.writerow(['ts', 'client_app', 'server_app', 'ingress_bytes', 'ingress_packets', \
        'egress_bytes', 'egress_packets', 'rtt', 'handshake_rtt', 'out_of_order', 'retransmits'])
        
        for obs in convo_graph['observations']:
            c.writerow([time.time(), obs['client'], obs['server'], obs['traffic']['ingressOctets'], \
            obs['traffic']['ingressPackets'], obs['traffic']['egressOctets'], \
            obs['traffic']['egressPackets'], obs['traffic']['appRttUsec'], \
            obs['traffic']['handshakeRttUsec'], obs['traffic']['outOfOrder'], \
            obs['traffic']['retransmits']])

    # Kick things off!
    def run(self):
        apps = self.get_applications()
        meters = self.get_meters()
        convo_graph = self.get_convo_graph()
        meter_info = {int(m['obs_domain_id']): m['name'] for m in meters}

        app_map = self.build_app_map(apps, meter_info)
        host_to_app_map = self.build_host_to_app_map(apps, meter_info)
        self.write_app_map(app_map)
        self.write_host_to_app_map(host_to_app_map)
        self.write_meter_info(meters)
        self.write_app_to_app(apps, convo_graph)

        logging.info('Done!')

if __name__ == '__main__':
    if 'SPLUNK_HOME' in os.environ:
        path = os.environ['SPLUNK_HOME']+'/etc/apps/boundary/local/boundary.conf'
    else:
        path = '../local/boundary.conf'

    Boundary(path).run()
