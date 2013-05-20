### Boundary Event System Plugins

This repository contains examples and scripts of how to join external systems to Boundary's event system API's. Each directory includes code, documentation and configuration for a particular system, such as nagios or pingdom. The purpose of this code is to take events from these external systems and populate your Boundary dashboard with them.

If you are looking for the Chef event handler for Boundary's event system look no further than [here](https://github.com/boundary/chef-boundary-events-handler). Alternatively the puppet module can be found [here](https://github.com/puppetlabs/puppetlabs-boundary).

We are happy to accept pull requests for existing support and include additional support for monitoring systems not included in this repository. Just open a PR!

All of the code in this repository is made available under the Apache 2.0 License.