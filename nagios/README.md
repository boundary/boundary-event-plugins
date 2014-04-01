# Nagios Boundary Event Handler

## Introduction

Nagios is integrated to Boundary via Nagios event handlers. Nagios
Event handlers are optional system commands (scripts or executables)
that are run whenever a host or service state change occurs.

Specifically the Boundary event integration uses Nagio's global event handlers
to execute a custom script when a Nagios service or host:

* Is in a **SOFT** problem state
* Initially goes into a **HARD** problem state
* Initially recovers from a **SOFT** or **HARD** problem state

When the boundary script is executed it then creates/updates events via the Boundary Event API

NOTE: Details of soft and hard problem state are beyond the scope of this documentation, but information
regarding these states can be found online at http://www.nagios.org/documentation

### Prerequisites

- Ruby 1.9.3 or later (It is highly recommended that you use RVM (Ruby Version Manager) to install,
                       details on using RVM for installation are described below.)
- curl is available on the Nagios system.

## Installation and Configuration
Sections below describe the details of installing the Boundary Event Integration to Nagios.

### A Note on Nagios Installation File Layout and Permissions
* A typical Nagios installation defines a unix user nagios and a unix group nagcmd to assign user and group file permissions.
Other access is not usually enabled. The instructions that follow provide explicity commands to ensure that the owner
and groups are set correctly, along with permssions. If you installation uses different user names and/or groups
subsitute the appropriate values in the commands below.
* The typical location to install Nagios in the file system is `/usr/local/nagios`. Should your installation be installed
in another location please subsitute the correct path for `/usr/local/nagios` in the commands below.

### Checking for Prerequisites
Check to ensure that curl and git are installed on the Nagios system.

#### curl 
1. Become the nagios user or the user underwhich the Nagios process runs (typically `nagios`).
2. Run the following command to verify that curl is installed on your systems ```$ type curl```
3. Output result from running of the command should provide this output indicating that curl is installed ```curl is /usr/bin/curl```
4. Or, the following output indicating that curl is NOT installed. ```-bash: type: curl: not found```
5. Repeat this steps above but

If either curl is not installed on the system then install the appropriate package for your operating system.

### Installing Ruby 1.9.3
The preferred way to install Ruby to support running the Nagios Boundary Event Handler is using
RVM (Ruby Version Manager). Using RVM to install the Ruby interpreter avoids having to install/upgrade
the Ruby interpreter in use on the entire system where your Nagios instance is running. RVM
installs as regular unix user and does not require root priviledges. Typically this
is the unix user _nagios_.

Installing Ruby using RVM is a two step process that includes:

1. Installing RVM environment
2. Installing required Ruby version

#### Installing RVM
1. Become the nagios user or the user underwhich the Nagios process runs (typically `nagios`).
2. Run the following command: \curl -sSL https://get.rvm.io | bash -s stable
3. source /home/nagios/.rvm/scripts/rvm

### Installing Ruby
1. Become the nagios user or the user underwhich the Nagios process runs
3. Run the command: ```rvm install 1.9.3```
4. Verify that the correct version of Ruby is installed: ```ruby —-version```
5. nagios@ip-10-120-70-131:~$ ruby --version
ruby 1.9.3p545 (2014-02-24 revision 45159) [x86_64-linux]

### Download the Integration Distribution from GitHub

1. Become the nagios user or the user underwhich the Nagios process runs (typically `nagios`).
2. Change to home directory: ```cd ~```
3. Run the following command: ```curl -L https://github.com/boundary/boundary-event-plugins/archive/master.zip > master.zip```
4. Extract the archive ```unzip master.zip```
4. This creates a new directory named boundary-event-plugins

### Installing
Boundary's integration requires installing the following files in the Nagios installation:

1. Event handler script
2. Event handler script configuration file
3. Certificate use by event handler script

Additionally configuration files in the Nagios installation are required to be modified, which requires that Nagios be restarted:

1. Enable event handlers
2. Enable logging of event handlers
3. Set Event Handler timeout
4. Assign global host and service event handlers

NOTE: All of the following procedures should be performed as the nagios user or the user underwhich the Nagios process runs

#### Add Event Handler Script

1. Change directory to the Nagios integration: ```cd ~/boundary-event-plugins/nagios```.
2. Ensure that eventhandlers directory exists: ```mkdir -p /usr/local/nagios/libexec/eventhandlers```.
3. Copy the Boundary event handling script to Nagios installation: ```cp nagios-boundary-event-handler.rb /usr/local/nagios/libexec/eventhandlers/```.
4. Set owner and group on the file: ```sudo chown nagios:nagcmd /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rbi```.
5. Set owner and group permissions on the file: ```sudo chmod 0550 /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb```.
6. Verify ownership and permissions by running: ```ls -l /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb```.
7. Output should resemble the following:```-r-xr-x--- 1 nagios nagios 5153 Mar 25 22:25 /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb```.

#### Add Event Handler Script Configuration File
1. Change directory to the Nagios integration: ```cd ~/boundary-event-plugins/nagios```.
2. Copy the Boundary event handling script to Nagios installation: ```cp nagios-boundary-event-handler.rb /usr/local/nagios/libexec/eventhandlers/```.

#### Add Certificate
1. Change directory to the Nagios integration: ```cd ~/boundary-event-plugins/common```.
2. Copy the Boundary certificate to Nagios installation: ```cp  cacert.pem /usr/local/nagios/libexec/eventhandlers/```.

#### Add Nagios Event Handler Configuration
1. Change directory to the Nagios integration: ```cd ~/boundary-event-plugins/nagios```.
2. Copy the Boundary certificate to Nagios installation: ```cat boundary_event_handlers_core.cfg >> /usr/local/nagios/etc/objects/commands.cfg```.

#### Add/Update Configuration To Enable Event Handlers

1) Make the redirected files to standard out and standard err.

2) Ensure that the RVM environment accurately picks up the correct version of Ruby

3) Enable the log to make sure its firing correctly.


Add Event Handler Script


  1. cp nagios-boundary-event-handler.rb /usr/local/nagios/libexec/eventhandlers/

  2. sudo chown nagios:nagcmd /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb

  3. sudo chmod 0550 /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb

  4. Verify:  ls -l /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb

Ensure that log files can written by nagios and members of the nagcmd group


Error Log


  1. touch /usr/local/nagios/libexec/eventhandlers/boundary-err.txt

  2. sudo chown nagios:nagcmd /usr/local/nagios/libexec/eventhandlers/boundary-err.txt

  3. sudo chmod  0660 /usr/local/nagios/libexec/eventhandlers/boundary-err.txt

  4. ls -l /usr/local/nagios/libexec/eventhandlers/boundary-err.txt


Standard Out Log


  1. touch /usr/local/nagios/libexec/eventhandlers/boundary-out.txt

  2. sudo chown nagios:nagcmd /usr/local/nagios/libexec/eventhandlers/boundary-out.txt

  3. sudo chmod  0660 /usr/local/nagios/libexec/eventhandlers/boundary-out.txt

  4. ls -l /usr/local/nagios/libexec/eventhandlers/boundary-out.tx



Add Certificate


  1. cp ../common/cacert.pem /usr/local/nagios/libexec/eventhandlers/

  2. sudo chown nagios:nagcmd /usr/local/nagios/libexec/eventhandlers/cacert.pem

  3. sudo chmod 0440 /usr/local/nagios/libexec/eventhandlers/cacert.pem


Add Boundary Configuration File


  1. cp boundary.yml /usr/local/nagios/etc *

  2. vi /usr/local/nagios/etc/boundary.yml # Modify to add send, api key, and orgid
  3. sudo chown nagios:nagcmd /usr/local/nagios/etc/boundary.yml

  4. sudo chmod 0440 /usr/local/nagios/etc/boundary.yml

  5. Verify:  ls -l /usr/local/nagios/etc/boundary.yml

Modify Nagios Configuration to install Boundary Commands


  1. vi boundary_event_handler.cfg, rename referenced files
  2. cat boundary_event_handler.cfg >> /usr/local/nagios/etc/objects/commands.cfg
  3. verify:  tail -15 /usr/local/nagios/etc/objects/commands.cfg
  4. verify:  ls -l /usr/local/nagios/etc/objects/commands.cfg # NOTE: the default is not adding nagcmd
  5. /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg


Enable USER2 macro:


  1. vi /usr/local/nagios/etc/resource.cfg # Uncomment $USER2$ variable which points to /usr/local/nagios/libexec/eventhanders




Modify Nagios Configuration


  1. Check:  grep log_event_handlers /usr/local/nagios/etc/nagios.cfg
  2. Check:  grep event_handler_timeout /usr/local/nagios/etc/nagios.cfg
  3. Check:  grep enable_event_handlers /usr/local/nagios/etc/nagios.cfg
  4. cat boundary_global_event_handler.cfg >> /usr/local/nagios/etc/nagios.cfg

  5. Verify:  tail -10 /usr/local/nagios/etc/nagios.cfg
  6. Verify: 



Get Nagios Integration to Nagios




Add Event Handler Script


  1. cd nagios
  2. cp




  1. cat boundary_eventshandler.mk >> /usr/local/nagios/etc/objects/commands.cfg . OMD only need to add a file for Nagios core.

  2. Rename referenced scripts add “nagios-“

  3. Ensure these parameters are set: log_event_handlers=1, event_handler_timeout=30, enable_event_handlers=1
  4. /usr/local/nagios/etc/resource.cfg $USER2$=/usr/local/nagios/libexec/eventhandlers

  5. Modify script nagios-boundary-event-handler (SEE figure 1 below)
  6. Configure event handlers (SEE figure 2 below)
  7. Add cert to nagios:  cp ../common/cacert.pem /usr/local/nagios/libexec/eventhandlers/
  8. Add nagios-boundary-event-handler.rb:  cp nagios-boundary-event-handler.rb /usr/local/nagios/libexec/eventhandlers/
  9. Copy boundary configuration to nagios:  cp boundary.yml /usr/local/nagios/etc
  10. Add api key and organization id to /usr/local/nagios/etc/boundary.yml
  11. To verify nagios configuration:  /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg 
  12. Restart nagios:  sudo service nagios restart



Monitoring


  1. Set debug_level=256 to have a log written to where debug_log file is specified
  2. Set debug_verbosity=2







Testing Configuration


  1. Disable flap detection  enable_flap_detection=0





Figure 1:
define command {  command_name    handle_boundary_event_host  command_line    $USER1$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e host -s $HOSTSTATE$ -t $HOSTSTATETYPE$ -a $HOSTATTEMPT$ -o "$LONGHOSTOUTPUT$"}define command {  command_name    handle_boundary_event_service  command_line    $USER1$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e service -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -a $SERVICEATTEMPT$ -o "$LONGSERVICEOUTPUT$"}


Figure 2:


global_host_event_handler=handle_boundary_event_hostglobal_service_event_handler=handle_boundary_event_service




Configuration Errors



Error: Could not open command file '/usr/local/nagios/var/rw/nagios.cmd' for update!


The permissions on the external command file and/or directory may be incorrect. Read the FAQs on how to setup proper permissions.


An error occurred while attempting to commit your command for processing.

Return from whence you came


BOUNDARY_API_HOST = "api.boundary.com"
#BOUNDARY_CONFIG_PATH = "/etc/nagios3/boundary.yml"
BOUNDARY_CONFIG_PATH = "/usr/local/nagios/etc/boundary.yml"
#CACERT_PATH = "#{File.dirname(__FILE__)}/../common/cacert.pem"
CACERT_PATH = "#{File.dirname(__FILE__)}/cacert.pem"




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
