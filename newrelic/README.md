New Relic Event Webhook
=======================

This directory contains a standalone python webhook which understands New Relic event calls and forwards them onto Boundary using the event API.

Installation
------------

Copy `newrelic-webhook.py` and `newrelic-webhook.cfg` to a directory (e.g. `/opt/boundary/bin`). Edit the `newrelic-webhook.cfg` file and set the appropiate values for the `api-key` and `organization-id` settings, optionally change the values for `host` and `port` which is where the webserver will listen.

Configuration
-------------

To enable the webhook in New Relic
* Visit https://rpm.newrelic.com/accounts/103901/alert_policies#tab-alert_policies=notification_channels_tab
* Click Create Channel -> Webhook 
* Enter the address address the webhook will be accessible from  
* Click Integrate with Webhooks

Usage
-----
```
Usage: newrelic-webhook.py
```
