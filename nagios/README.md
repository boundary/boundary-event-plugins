Nagios Boundary Events Handler
===

This script is for use with Nagios to send host and service status changes to the Boundary Event service.

Requirements
---

- Boundary API SSL CA certificate, located here: [cacert.pem] (https://raw.github.com/boundary/boundary-event-plugins/master/common/cacert.pem) 
- Ruby 1.9.3 or later ([RVM] (http://rvm.io/rvm/install) is recommended for upgrading where necessary)
- Ruby [gems installer] (http://rubygems.org/pages/download)
- These gems - json, uri, yaml

Setup
---

1) Install the handler script in your plugin directory.

2) Add the config file `boundary.yml` to `/etc/nagios3/boundary.yml` (If you choose a different directory, you'll need to update the `BOUNDARY_CONFIG_PATH` variable in the script.) and ensure it has the following settings:

- sender: <the fqdn of your Nagios server as it would appear in Boundary>
- apikey: <your Boundary api key>
- orgid: <your Boundary orgid>

3) Install the Boundary API SSL CA certificate somewhere and update the `CACERT_PATH` variable in the script to reflect this path.

4) Verify that the nagios-boundary-event-handler.rb configuration is correct by creating a test event into boundary:

$ nagios-boundary-event-handler.rb -H "MyHost" -e host -s OK -t HARD -a 1 -o Test

Check the event console to ensure that an event is created.

5) Add the following commands to your Nagios instance:

    define command {
      command_name    handle_boundary_event_host
      command_line    $USER1$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e host -s $HOSTSTATE$ -t $HOSTSTATETYPE$ -a $HOSTATTEMPT$ -o "$LONGHOSTOUTPUT$"
    }

    define command {
      command_name    handle_boundary_event_service
      command_line    $USER1$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e service -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -a $SERVICEATTEMPT$ -o "$LONGSERVICEOUTPUT$"
    }

6) Add the following to your `nagios.cfg` (the first three lines may already exist):

    log_event_handlers=1
    event_handler_timeout=30
    enable_event_handlers=1
    global_host_event_handler=handle_boundary_event_host
    global_service_event_handler=handle_boundary_event_service

7) Restart Nagios!

For OMD implementations
---
The boundary_eventhandlers.mk file should be placed in the $OMD_ROOT/etc/check_mk/conf.d directory and will be applied to the managed Nagios instance once OMD is restarted.
