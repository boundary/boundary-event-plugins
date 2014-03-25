This adapter can be used for adding annotations to Boundary from Zabbix.

The two files included in this repo should be in the same directory.

Pre-requisites

This adapter is written for and works best on Linux and UNIX based operating systems. 

It requires: 

1. Ruby 1.9.3 or later ([RVM] (http://rvm.io/rvm/install) is recommended for upgrading where necessary)
2. Ruby [gems installer] (http://rubygems.org/pages/download)
3. These gems - json, httparty, rsolr

How to Use

1. Set up the script

- Fill-in Zabbix IP/hostname/address into variable ZABBIX_API_HOST
- Fill in Zabbix username and password into ZABBIX_USER and ZABBIX_PASSWORD

- Fill in BOUNDARY_ORGID and BOUNDARY_APIKEY
- Set  window query parameter: WINDOW. This parameter controls how far back in time to query for triggers that have had their state changed
- Set the logging level (default is INFO)


2. Schedule the script to run more frequenty then the WINDOW setting

