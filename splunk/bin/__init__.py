#!/usr/bin/env python
"""Splunk App for Boundary."""

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


from .boundary import (get_api_credentials, search_command, alert_command,
    get_config_file, setup_apiclient, main)
