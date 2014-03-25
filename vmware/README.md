VMware Event Adapter
====================

The Boudary VMware event adapater is a standalone java application which continually polls a single VMware vSphere server for events and forwards them to Boundary.

The source is currently not available but the binary file can be downloaded from https://s3.amazonaws.com/boundary-utils/boundary-event-adapters/vmware/vmware-events-1.2.jar

The VMware event adapter can be downloaded and placed in any path. For example /opt/boundary/vmware along with a configuration file as described.

Configuration
-------------

```
boundary:
  apiKey: AAABBBCCC
  orgId: AAABBBCCC
  httpClient:
    timeout: 10s
    connectionTimeout: 10s
vmware:
  url: https://vsphere/sdk
  username: root
  password: vmware
  verifyCertificate: false
  stateFile: .state
  pollFrequency: 1m
```

**apiKey**
* Boundary API key 

**orgId**
* Boundary organisation ID

**url**
* Full path to VMware vSphere SDK 

**stateFile**
* Path to file used to store last information about last event retrieved

**pollFrequency**
* Frequency at which the VMware event adapater should poll VMware vSphere for new events

Usage
-----
Start the jar file: java -jar vmware-events-1.2.jar configfile.yml
