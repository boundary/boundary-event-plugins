servicenow
==========

snowbound.py is a python based script which creates tickets from Boundary events that are found for a specified query. 

It leverages the Boundary Events API:
https://app.boundary.com/docs/events_api

And ServiceNow Web Services API:
http://wiki.servicenow.com/index.php?title=JSON_Web_Service

It uses a configuration file (snowbound.cfg) to capture Boundary and ServiceNow URLs, credentials and settings. This is also where the event query can be entered. The example cfg file contained in this repo contains a query for events with Critical severity that do not have a tag for "ticketed".

The script will create a ticket from event data and designate a short description, priority and place the event message, severity and id in the work notes of the ticket along with a direct link to the Boundary event. In addition, it will retain the ticket id and place that as a tag in the event along with a deep link to the ticket in the event properties section.
