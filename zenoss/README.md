Zenoss Event Plug-ins
=====================

In this directory is a script which can be used to forward events from a Zenoss 3.x system to Boundary's Events API. The script is meant to be run as an Event Command in Zenoss.

Installation
------------

To install the script, copy the `boundary-zenoss3.cfg` and `boundary-zenoss3.py` files to a directory on the Zenoss master (i.e. `/opt/boundary/bin`). Open the `boundary-zenoss3.cfg` file in an editor and set the appropriate values for the `api-key` and `organization-id` settings. Make sure that both files are readable by the `zenoss` user and the `boundary-zenoss3.py` script is executable.

Configuration
-------------

To configure the Event Command, perform the following
steps in the Zenoss UI:

* Navigate to Events -> Event Manager -> Commands.
* Specify a command name and click 'Add'.
* Click on the link for the created command to edit its settings.
* Assuming the script has been installed to the `/opt/boundary/bin` directory, specify the following in the 'Command' field:

```
/opt/boundary/bin/boundary-zenoss3.py --fingerprint-field evid --property 'evid=${evt/evid}' --source-ref '${evt/device}' --created-at '${evt/lastTime}' --property  'component=${evt/component}' --property 'eventClass=${evt/eventClass}' --property 'eventKey=${evt/eventKey}' --title '${evt/summary}' --message '${evt/message}' --zenoss-severity ${evt/severity} --zenoss-state ${evt/eventState} --property 'eventClassKey=${evt/eventClassKey}' --property 'eventGroup=${evt/eventGroup}' --property 'stateChange=${evt/stateChange}' --property 'firstTime=${evt/firstTime}' --property 'lastTime=${evt/lastTime}' --property 'prodState=${evt/prodState}' --property 'suppid=${evt/suppid}' --property 'manager=${evt/manager}' --property 'agent=${evt/agent}' --property 'DeviceClass=${evt/DeviceClass}' --property 'Location=${evt/Location}' --property 'Systems=${evt/Systems}' --property 'DeviceGroups=${evt/DeviceGroups}' --property 'ipAddress=${evt/ipAddress}' --property 'facility=${evt/facility}' --property 'priority=${evt/priority}' --property 'nvevid=${evt/ntevid}' --property 'ownerid=${evt/ownerid}' --property 'clearid=${evt/clearid}' --property 'DevicePriority=${evt/DevicePriority}' --property 'eventClassMapping=${evt/eventClassMapping}' --property 'monitor=${evt/monitor}'
```

* Specify this in the 'Clear Command' field:

```
/opt/boundary/bin/boundary-zenoss3.py --fingerprint-field evid --property 'evid=${evt/evid}' --source-ref '${evt/device}' --created-at '${evt/lastTime}' --property  'component=${evt/component}' --property 'eventClass=${evt/eventClass}' --property 'eventKey=${evt/eventKey}' --title '${evt/summary}' --message '${evt/message}' --zenoss-severity ${evt/severity} --status CLOSED --property 'eventClassKey=${evt/eventClassKey}' --property 'eventGroup=${evt/eventGroup}' --property 'stateChange=${evt/stateChange}' --property 'firstTime=${evt/firstTime}' --property 'lastTime=${evt/lastTime}' --property 'prodState=${evt/prodState}' --property 'suppid=${evt/suppid}' --property 'manager=${evt/manager}' --property 'agent=${evt/agent}' --property 'DeviceClass=${evt/DeviceClass}' --property 'Location=${evt/Location}' --property 'Systems=${evt/Systems}' --property 'DeviceGroups=${evt/DeviceGroups}' --property 'ipAddress=${evt/ipAddress}' --property 'facility=${evt/facility}' --property 'priority=${evt/priority}' --property 'nvevid=${evt/ntevid}' --property 'ownerid=${evt/ownerid}' --property 'clearid=${evt/clearid}' --property 'DevicePriority=${evt/DevicePriority}' --property 'eventClassMapping=${evt/eventClassMapping}' --property 'monitor=${evt/monitor}'
```

* Add a filter to match the events to be forwarded to Boundary, and enable the Event Command.

Usage
-------------

```
Usage: boundary-zenoss3.py [options]

Options:
  -h, --help            show this help message and exit

  Required Options:
    --api-key=API_KEY   Boundary API Key
    --organization-id=ORGANIZATION_ID
                        Boundary Organization
    --title=TITLE       Event Title
    --fingerprint-field=FINGERPRINT_FIELDS
                        Fingerprint Field (at least one is required)
    --source-ref=SOURCE_REF
                        Source Reference (required)

  Additional Options:
    --message=MESSAGE   Event Message
    --property="KEY=VALUE"
                        Free-form properties to set on event
    --tag=TAGS          Tags to add to event
    --severity=SEVERITY
                        Severity (INFO/WARN/ERROR/CRITICAL)
    --zenoss-severity=ZENOSS_SEVERITY
                        Zenoss Event Severity (0-5)
    --source-type=SOURCE_TYPE
                        Source Type (default: host)
    --source-property="KEY=VALUE"
                        Source Property
    --sender-ref=SENDER_REF
                        Sender Reference (default: tweekbook.local)
    --sender-type=SENDER_TYPE
                        Sender Type
    --sender-property="KEY=VALUE"
                        Sender Property
    --status=STATUS     Boundary Event Status (OPEN/CLOSED/ACKNOWLEDGED/OK)
    --zenoss-state=ZENOSS_STATE
                        Zenoss Event State (0-2)
    --created-at=CREATED_AT
                        The event creation time (a UTC date/time or
                        milliseconds since epoch)
```