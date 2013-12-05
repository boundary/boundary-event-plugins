This adapter can be used for adding annotations to Boundary from Zabbix.

The two files included in this repo should be in the same directory.

How to Use

1. Set up the script

- Fill-in Zabbix IP/hostname/address into variable ZABBIX_API_HOST
- Fill in Zabbix username and password into ZABBIX_USER and ZABBIX_PASSWORD

- Fill in Boundary APIKey and OrgID
- Set polling period in seconds into POLLING_PERIOD - this should coincide with frequency of checking Zabbix for new alerts - recommended value = 60 seconds

2. Schedule the script 

- crontab it to run at a frequency
- Make sure the frequency matches the POLLING_PERIOD setting
