Chef Boundary Events Handler
===

This is a Chef handler for taking successful changes and exceptions via Chef and creating Boundary Events from them.

Requirements
---

You will need your Boundary Org ID and API key.

This cookbook requires the "chef_handler" cookbook.

Setup
---

Create a data bag named "boundary/account" with the json:

    {
      "id": "account",
      "orgid": "your-orgid-here",
      "apikey": "your-apikey-here"
    }

Add the `chef-boundary-events-handler` cookbook your node - via run_list, to a "base" cookbook, whatever works best for your environment
