This adapter can be used for adding annotations to Boundary from Zabbix.

The two files included in this repo should be in the same directory.

Pre-requisites

This adapter is written for and works best on Linux and UNIX based operating systems. 

It requires: 

1. Ruby 1.9.3 or later (RVM is recommended for upgrading where necessary)
2. Ruby gems package manager
3. These gems - json, httparty, rsolr

How to Use

1. Set up the script

- Fill-in Zabbix IP/hostname/address into variable ZABBIX_API_HOST
- Fill in Zabbix username and password into ZABBIX_USER and ZABBIX_PASSWORD

- Fill in Boundary APIKey and OrgID
- Set polling period in seconds into POLLING_PERIOD - this should coincide with frequency of checking Zabbix for new alerts - recommended value = 60 seconds

2. Schedule the script 

- crontab it to run at a frequency
- Make sure the frequency matches the POLLING_PERIOD setting
