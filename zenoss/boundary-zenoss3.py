#!/usr/bin/env python

"""
Script used to forward Zenoss 3.x events into Boundary's events API via event commands.
"""

import json
import logging
import os
import socket
import time
import urllib2
from ConfigParser import SafeConfigParser
from base64 import b64encode

LOG = logging.getLogger('boundary-zenoss3')

API_ENDPOINT = "https://api.boundary.com"

STATUS_MAP = {
    0: "OPEN",
    1: "ACKNOWLEDGED",
    2: "OPEN",  # No mapping for suppressed state
}

SEVERITY_MAP = {
    0: "INFO",
    1: "INFO",
    2: "INFO",
    3: "WARN",
    4: "ERROR",
    5: "CRITICAL",
}


def load_defaults():
    cfg_file = os.path.join(os.path.dirname(__file__), "boundary-zenoss3.cfg")
    defaults = {}
    if os.path.isfile(cfg_file):
        config = SafeConfigParser()
        config.read(cfg_file)

        def set_default(option_name):
            if config.has_option("boundary", option_name):
                value = config.get("boundary", option_name).strip()
                if value:
                    defaults[option_name] = value

        for setting in ("api-key", "organization-id"):
            set_default(setting)
    LOG.debug("Option Defaults: %s", defaults)
    return defaults


def send_event(event, organization, api_key):
    url = "/".join((API_ENDPOINT, organization, "events"))
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Basic %s" % b64encode("%s:" % api_key),
    }
    LOG.debug("URL: %s, Headers: %s, Payload: %s", url, headers,
              json.dumps(event, indent=4, sort_keys=True))
    request = urllib2.Request(url, json.dumps(event), headers=headers)
    try:
        response = urllib2.urlopen(request)
        response_data = response.read()
        if 'Location' not in response.headers:
            LOG.error("Failed to create event in Boundary API: %s (%d)",
                      response.msg, response.code, response_data)
            raise RuntimeError("Unknown response from Boundary API")
        event_id = response.headers['Location'].rsplit('/', 1)[-1]
        LOG.info("Created event '%s' in Boundary", event_id)
    except urllib2.HTTPError as e:
        LOG.error("Error sending event to Boundary API: %s (%d), Error: %s\nPayload: %s",
                  getattr(e, "reason", "Unknown Reason"),
                  e.code, e.read(), json.dumps(event, indent=4, sort_keys=True))
        raise


def create_properties_dictionary(kv_list):
    properties = {}
    if kv_list:
        for kv in kv_list:
            try:
                key, value = kv.split("=", 1)
                if key and value:
                    properties[key] = value
            except ValueError:
                LOG.error("Invalid property key/value: %s", kv)
    return properties


def truncate_to_length(value, length):
    if len(value) > length:
        value = value[:length-3] + "..."
    return value


def convert_zenoss_date_time(zenoss_date_time):
    """
    Attempts to convert a Zenoss date/time format from an event into
    a time suitable for the createdAt field of a Boundary event
    (represented as milliseconds since the unix epoch).

    Zenoss event times use the format %Y/%m/%d %H:%M:%%06.3f, but the
    milliseconds in the time are always set to zero.
    """
    if '.' in zenoss_date_time:
        zenoss_date_time = zenoss_date_time.split('.', 1)[0]
    try:
        tm = time.strptime(zenoss_date_time, "%Y/%m/%d %H:%M:%S")
        return int(time.mktime(tm) * 1000)
    except ValueError:
        return zenoss_date_time


def main():
    logging.basicConfig()
    logging.root.setLevel(logging.INFO)
    for handler in logging.root.handlers:
        handler.level = logging.INFO
    defaults = load_defaults()
    import optparse
    parser = optparse.OptionParser(usage="%prog [options]")

    required_group = parser.add_option_group("Required Options")
    required_group.add_option("--api-key",
                              default=defaults.get("api-key"),
                              help="Boundary API Key")
    required_group.add_option("--organization-id",
                              default=defaults.get("organization-id"),
                              help="Boundary Organization")
    required_group.add_option("--title",
                              help="Event Title")
    required_group.add_option("--fingerprint-field",
                              action="append",
                              dest="fingerprint_fields",
                              help="Fingerprint Field (at least one is required)")
    required_group.add_option("--source-ref",
                              help="Source Reference (required)")

    additional_group = parser.add_option_group("Additional Options")
    additional_group.add_option("--message",
                                help="Event Message")
    additional_group.add_option("--property",
                                action="append",
                                dest="properties",
                                help="Free-form properties to set on event",
                                metavar="\"KEY=VALUE\"")
    additional_group.add_option("--tag",
                                action="append",
                                dest="tags",
                                help="Tags to add to event")
    additional_group.add_option("--severity",
                                choices=["INFO", "WARN", "ERROR", "CRITICAL"],
                                help="Severity (INFO/WARN/ERROR/CRITICAL)")
    additional_group.add_option("--zenoss-severity",
                                choices=map(str, range(0, 6)),
                                help="Zenoss Event Severity (0-5)")
    additional_group.add_option("--source-type",
                                default="host",
                                help="Source Type (default: %default)")
    additional_group.add_option("--source-property",
                                action="append",
                                dest="source_properties",
                                metavar="\"KEY=VALUE\"",
                                help="Source Property")

    additional_group.add_option("--sender-ref",
                                default=socket.getfqdn(),
                                help="Sender Reference (default: %default)")
    additional_group.add_option("--sender-type",
                                default="zenoss",
                                help="Sender Type")
    additional_group.add_option("--sender-property",
                                action="append",
                                dest="sender_properties",
                                metavar="\"KEY=VALUE\"",
                                help="Sender Property")

    additional_group.add_option("--status",
                                choices=["OPEN", "ACKNOWLEDGED", "CLOSED", "OK"],
                                help="Boundary Event Status (OPEN/CLOSED/ACKNOWLEDGED/OK)")
    additional_group.add_option("--zenoss-state",
                                choices=map(str, range(0, 3)),
                                help="Zenoss Event State (0-2)")

    additional_group.add_option("--created-at",
                                default=str(int(time.time()*1000)),
                                help="The event creation time (a UTC date/time or milliseconds since epoch)")

    options, args = parser.parse_args()
    for required_option in required_group.option_list:
        if not getattr(options, required_option.dest, None):
            parser.error("Required option: %s not specified" % required_option.get_opt_string())

    if options.status and options.zenoss_state:
        parser.error("Options --status and --zenoss-state are mutually exclusive")
    if options.severity and options.zenoss_severity:
        parser.error("Options --severity and --zenoss-severity are mutuallly exclusive")

    event = {
        "source": {
            "ref": options.source_ref,
            "type": options.source_type,
        },
        "sender": {
            "ref": options.sender_ref,
            "type": options.sender_type,
        },
        "fingerprintFields": options.fingerprint_fields,
        "title": truncate_to_length(options.title, 255),
    }

    status = options.status
    if options.zenoss_state:
        status = STATUS_MAP.get(int(options.zenoss_state))
    if status:
        event["status"] = status

    severity = options.severity
    if options.zenoss_severity:
        severity = SEVERITY_MAP.get(int(options.zenoss_severity))
    if severity:
        event["severity"] = severity

    if options.tags:
        event["tags"] = options.tags

    if options.message:
        event["message"] = truncate_to_length(options.message, 255)

    if options.created_at:
        try:
            event["createdAt"] = int(options.created_at)
        except ValueError:
            # Try to parse Zenoss firstTime/lastTime format
            event["createdAt"] = convert_zenoss_date_time(options.created_at)

    for parent_dict, option_value in ((event, options.properties),
                                      (event["source"], options.source_properties),
                                      (event["sender"], options.sender_properties)):
        properties_dict = create_properties_dictionary(option_value)
        if properties_dict:
            parent_dict["properties"] = properties_dict

    send_event(event, options.organization_id, options.api_key)

if __name__ == "__main__":
    try:
        main()
    except Exception:
        LOG.exception("Failed to send event to Boundary API")
        raise
