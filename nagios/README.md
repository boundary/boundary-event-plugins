# Boundary Event Integration to Nagios

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
- curl and unzip is available on the Nagios system.

## Installation and Configuration
Sections below describe the details of installing the Boundary Event Integration to Nagios.

### A Note on Nagios Installation File Layout and Permissions
* A typical Nagios installation defines a unix user nagios and a unix group nagios to assign user and group file permissions.
Other access is not usually enabled. The instructions that follow provide explicit commands to ensure that the owner
and groups are set correctly, along with permssions. If your installation uses different user names and/or groups
subsitute the appropriate values in the commands below.
* The typical location to install Nagios in the file system is `/usr/local/nagios`. Should your installation be installed
in another location please subsitute the correct path for `/usr/local/nagios` in the commands below.

### Checking for Prerequisites
Check to ensure that curl and unzip are installed on the Nagios system. These commands are required to complete
the installation of the integration.

#### curl 
1. Become the nagios user or the user underwhich the Nagios process runs (typically `nagios`).
2. Run the following command to verify that curl is installed on your systems ```$ type curl```
3. Output result from running of the command should provide this output indicating that curl is installed ```curl is /usr/bin/curl```
4. Or, the following output indicating that curl is NOT installed. ```-bash: type: curl: not found```
5. Repeat this steps above but replacing curl with unzip.

If either curl or unzip is not installed on the system then install the appropriate package or distribution for your operating system.

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
2. Run the following command: ```$ curl -sSL https://get.rvm.io | bash -s stable```
3. Include the RVM environment: ```$ source ~/.bash_profile```

#### Installing Ruby
1. Become the nagios user or the user underwhich the Nagios process runs
3. Run the command: ```$ rvm install 1.9.3```
4. Set the default ruby: ```rvm --default use 1.9.3```
5. Verify that the correct version of Ruby is installed: ```$ ruby —-version```

```ruby 1.9.3p545 (2014-02-24 revision 45159) [x86_64-linux]
```

### Installing the Integration
Boundary's integration requires installing the following files in the Nagios installation:

1. Event handler script
2. Event handler script configuration file
3. Certificate used by event handler script

Additionally configuration files in the Nagios installation are require modification, which in turn requires that Nagios be restarted:

1. Define event handler commands
2. Enable event handlers
3. Enable logging of event handlers
4. Set event handler timeout
5. Assign global host and service event handlers

NOTE: All of the following procedures should be performed as the nagios user or the user underwhich the Nagios process runs

#### Download the Integration Distribution from GitHub

1. Become the nagios user or the user underwhich the Nagios process runs (typically `nagios`).
2. Change to home directory: ```$ cd ~```
3. Run the following command: ```$ curl -L https://github.com/boundary/boundary-event-plugins/archive/master.zip > boundary-event-plugins.zip```
4. Extract the archive ```$ unzip boundary-event-plugins.zip```
4. This creates a new directory named boundary-event-plugins

#### Add Event Handler Script

1. Change directory to the Nagios integration: ```$ cd ~/boundary-event-plugins-master/nagios```.
2. Ensure that eventhandlers directory exists: ```$ mkdir -p /usr/local/nagios/libexec/eventhandlers```.
3. Copy the Boundary event handling script to Nagios installation: ```$ cp nagios-boundary-event-handler.rb /usr/local/nagios/libexec/eventhandlers/```.
4. Set owner and group on the file: ```$ chown nagios:nagios /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb```.
5. Set owner and group permissions on the file: ```$ chmod 0550 /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb```.
6. Verify ownership and permissions by running: ```$ ls -l /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb```.

```
-r-xr-x--- 1 nagios nagios 5153 Mar 25 22:25 /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb
```

#### Add Event Handler Script Configuration File
1. Change directory to the Nagios integration: ```$ cd ~/boundary-event-plugins-master/nagios```.
2. Edit the configuration file by adding source (typically the Nagios host), Boundary API Key and Organization ID. : ```$ vi boundary.yml```
3. Copy the Boundary event handling script to Nagios installation: ```$ cp boundary.yml /usr/local/nagios/libexec/eventhandlers```.
4. Configure ownership: ```$ chown nagios:nagios /usr/local/nagios/libexec/eventhandlers/boundary.yml```.
5. Configure permissions: ```$ chmod 0440 /usr/local/nagios/libexec/eventhandlers/boundary.yml```.
6. Verify ownership and permissions: ```$ ls -l /usr/local/nagios/libexec/eventhandlers/boundary.yml```.

```
-rw-rw-r--. 1 nagios nagios 93 Apr  2 16:27 /usr/local/nagios/libexec/eventhandlers/boundary.yml
```

#### Add Certificate
1. Change directory to the Nagios integration: ```$ cd ~/boundary-event-plugins-master/common```.
2. Copy the Boundary certificate to Nagios installation: ```$ cp  cacert.pem /usr/local/nagios/libexec/eventhandlers/```.
3. Configure ownership: ```$ chown nagios:nagios /usr/local/nagios/libexec/eventhandlers/cacert.pem```.
4. Configure permissions:  ```$ chmod 0440 /usr/local/nagios/libexec/eventhandlers/cacert.pem```.
5. Verify ownership and permissions: ```$ ls -l /usr/local/nagios/libexec/eventhandlers/cacert.pem```.

```
-r--r-----. 1 nagios nagios 216563 Apr  2 16:32 /usr/local/nagios/libexec/eventhandlers/cacert.pem
```

#### Verify Event Handler Script
1. Run the following command: ```$ /usr/local/nagios/libexec/eventhandlers/nagios-boundary-event-handler.rb -H "MyHost" -e host -s OK -t HARD -a 1 -o Test```
2. Verify that script executed succesfully: ```$ cat /usr/local/nagios/libexec/eventhandlers/boundary-out.txt```
3. Output in file should contain something similar to this: ```Created a Boundary Event @ NNNNNNNNN```
4. Check the Boundary Event Console to ensure that an event with the same event id has been created or exists.
5. If an event is not created then check for any errors: ```$ cat /usr/local/nagios/libexec/eventhandlers/boundary-err.txt```

#### Add Nagios Event Handler Command Definitions
1. Change directory to the Nagios integration: ```$ cd ~/boundary-event-plugins-master/nagios```.
2. Append the Boundary Command Definitions to the Nagios installation: ```$ cat boundary_command_definitions_core.cfg >> /usr/local/nagios/etc/objects/commands.cfg```.
3. Verify configuration was added: ```$ tail -10 /usr/local/nagios/etc/objects/commands.cfg```

```
define command {
  command_name    handle_boundary_event_host
  command_line    $USER2$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e host -s $HOSTSTATE$ -t $HOSTSTATETYPE$ -a $HOSTATTEMPT$ -o "$LONGHOSTOUTPUT$"
}

define command {
  command_name    handle_boundary_event_service
  command_line    $USER2$/nagios-boundary-event-handler.rb -H $HOSTADDRESS$ -e service -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -a $SERVICEATTEMPT$ -o "$LONGSERVICEOUTPUT$"
}

```

#### Enable USER2 Macro
NOTE: The following assumes a standard default Nagios installation. The USER2 macro is used by the commands that call the Boundary Event Handler script.
It assumed that the USER2 macro is defined as `/usr/local/nagios/libexec/eventhandlers`

1. Edit the resource configuration file: ```$ vi /usr/local/nagios/etc/resource.cfg```.
2. Uncomment $USER2$ variable which points to `/usr/local/nagios/libexec/eventhanders`.
3. Verify: ```$ grep USER2 /usr/local/nagios/etc/resource.cfg```

```
# Sets $USER2$ to be the path to event handlers
$USER2$=/usr/local/nagios/libexec/eventhandlers
```

#### Modify Nagios Event Handler Configuration
1. View current configuration: ```$ egrep "(enable_event_handlers|event_handler_timeout|log_event_handlers)" /usr/local/nagios/etc/nagios.cfg```
2. Edit the file, if needed, to set the appropriate values: ```$ vi /usr/local/nagios/etc/nagios.cfg```
3. Set `enable_event_handlers=1`
4. Set `event_handler_timeout=30`
5. Set `log_event_handlers=1`
6. Verify configuration: ```$ egrep "(enable_event_handlers|event_handler_timeout|log_event_handlers)" /usr/local/nagios/etc/nagios.cfg```

```
log_event_handlers=1
event_handler_timeout=30
enable_event_handlers=1
```

#### Assign Global Host and Service Event Handlers
1. Change directory to the Nagios integration: ```$ cd ~/boundary-event-plugins/nagios```.
2. Assign global host and service event handlers in Nagios installation: ```$ cat boundary_event_handlers_core.cfg >> /usr/local/nagios/etc/nagios.cfg```.
3. Verify: ```$ tail -2 /usr/local/nagios/etc/nagios.cfg```

```
global_host_event_handler=handle_boundary_event_host
global_service_event_handler=handle_boundary_event_service
```

#### Verify Nagios Configuration
1. To verify nagios configuration: ```$ /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg```.
2. Output will indicate errors, if any.

#### Restart Nagios
1. Restart nagios (assuming nagios user has sudo access): ```sudo /etc/init.d/nagios start```.

## Troubleshooting
Following sections provide procedures for troubleshooting the Boundary Event Handler integration.

### Enable Logging of Command Execution
To verify that nagios is calling the Boundary Event Handler script. Logging can be configured to show which commands are being executed by Nagios.

1. Edit the Nagios configure file: ```$ vi /usr/local/nagios/etc/nagios.cfg```
2. Set `logging_level=256`
3. Set `debug_verbosity=2` and save the configuration file
4. Verify values have been set correctly: ```$ egrep "(debug_level|debug_verbosity)" /usr/local/nagios/etc/nagios.cfg```
5. Verify nagios configuration: ```$ /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg```
6. Restart nagios (assuming nagios user has sudo access): ```sudo /etc/init.d/nagios start```

### Viewing Host or Service State Changes
Nagios creates log entries when the global event handlers are executed. With logging enabled these can be observed in the log file located here: `/usr/local/nagios/var/nagios.log`.

1. Trace the global event handlers by the following command: ```$ tail -f /usr/local/nagios/var/nagios.log | egrep "(GLOBAL SERVICE EVENT HANDLER|GLOBAL HOST EVENT HANDLER)" *.log```

