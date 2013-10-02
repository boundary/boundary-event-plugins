Nagios Boundary Events Handler
===

This script is for use with Nagios to send host and service status changes to the Boundary Event service.

Requirements
---

- Ruby
- Boundary API SSL CA certificate, located here: [cacert.pem] (https://github.com/boundary/boundary-event-plugins/tree/master/common) 

Setup
---

Install the handler script in your plugin directory.

Add the config file `boundary.yml` to `/etc/nagios3/boundary.yml` (If you choose a different directory, you'll need to update the `BOUNDARY_CONFIG_PATH` variable in the script.) and ensure it has the following settings:

- sender: <the fqdn of your Nagios server as it would appear in Boundary>
- apikey: <your Boundary api key>
- orgid: <your Boundary orgid>

Install the Boundary API SSL CA certificate somewhere and update the `CACERT_PATH` variable in the script to reflect this path.

Add the following commands to your Nagios instance:

    define command {
      command_name    handle_boundary_event_host
      command_line    $USER1$/boundary-event-handler.rb -H $HOSTADDRESS$ -e host -s $HOSTSTATE$ -t $HOSTSTATETYPE$ -a $HOSTATTEMPT$ -o $LONGHOSTOUTPUT$
    }

    define command {
      command_name    handle_boundary_event_service
      command_line    $USER1$/boundary-event-handler.rb -H $HOSTADDRESS$ -e service -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -a $SERVICEATTEMPT$ -o $LONGSERVICEOUTPUT$
    }

Add the following to your `nagios.cfg` (the first three lines may already exist):

    log_event_handlers=1
    event_handler_timeout=30
    enable_event_handlers=1
    global_host_event_handler=handle_boundary_event_host
    global_service_event_handler=handle_boundary_event_service

Restart Nagios!
