#!/usr/bin/env python
"""Boundary Splunk Setup REST Handler."""

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

import logging
import os
import shutil

import splunk.admin


class ConfigBoundaryApp(splunk.admin.MConfigHandler):
    """Boundary Splunk Setup REST Handler."""

    def setup(self):
        if self.requestedAction == splunk.admin.ACTION_EDIT:
            self.supportedArgs.addOptArg('api_key')
            self.supportedArgs.addOptArg('org_id')

    def handleList(self, confInfo):
        conf = self.readConf('boundary')
        if conf is not None:
            for stanza, settings in conf.items():
                for key, val in settings.items():
                    confInfo[stanza].append(key, val)

    def handleEdit(self, confInfo):
        if self.callerArgs.data['api_key'][0] in [None, '']:
            self.callerArgs.data['api_key'][0] = ''
        if self.callerArgs.data['org_id'][0] in [None, '']:
            self.callerArgs.data['org_id'][0] = ''

        self.writeConf('boundary', 'boundary', self.callerArgs.data)
        view_file = os.environ['SPLUNK_HOME']+'/etc/apps/boundary/default/data/ui/views/boundary.xml'
        view_template = os.environ['SPLUNK_HOME']+'/etc/apps/boundary/default/data/ui/views/boundary_default.xml'
        cmd = "sed 's/ORG_ID/%s/g' %s > %s" % (self.callerArgs.data['org_id'][0], view_template, view_file)
        logging.info(cmd)
        os.system(cmd)

        install_boundary_py(os.environ.get('SPLUNK_HOME'))


def install_boundary_py(splunk_home):
    """Copies boundary.py to Splunk's bin/scripts directory."""
    script_src = os.path.join(
        splunk_home, 'etc', 'apps', 'boundary', 'bin',
        'boundary.py')
    script_dest = os.path.join(splunk_home, 'bin', 'scripts')

    logging.info(
        "Copying script_src=%s to script_dest=%s" %
        (script_src, script_dest))
    shutil.copy(script_src, script_dest)


if __name__ == '__main__':
    splunk.admin.init(ConfigBoundaryApp, splunk.admin.CONTEXT_NONE)
