extra_nagios_conf += r"""

define command {
  command_name    handle_boundary_event_service
  command_line    $USER2$/nagios-boundary-event-handler.rb -H $HOSTNAME$ -e service -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -a $SERVICEATTEMPT$ -o "$SERVICEOUTPUT$" -d "$SERVICEDESC$"
}
"""

extra_nagios_conf += r"""

define command {
  command_name    handle_boundary_event_host
  command_line    $USER2$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e host -s $HOSTSTATE$ -t $HOSTSTATETYPE$ -a $HOSTATTEMPT$ -o $LONGHOSTOUTPUT$
}
"""

# Define event_handler for service
extra_service_conf["event_handler"] = [
        ( "handle_boundary_event_service", ALL_HOSTS, ALL_SERVICES),
]

# Define event_handler_enabled for service
extra_service_conf["event_handler_enabled"] = [
        ( "1", ALL_HOSTS, ALL_SERVICES),
]

extra_host_conf["event_handler"] = [
        ( "handle_boundary_event_host", ALL_HOSTS ),
]
extra_host_conf["event_handler_enabled"] = [
        ( "1", ALL_HOSTS ),
]
