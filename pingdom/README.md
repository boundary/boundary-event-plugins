Pingdom Boundary Events Handler

- PeriodicallyPolls Pingdom for newly-posted checks
- Finds out if these checks fall within the polling period
- Posts these checks out to Boundary Events Console

Configuration:
- Be sure to have the cacert.pem file located here: [cacert.pem] (https://github.com/boundary/boundary-event-plugins/tree/master/common), this is required for encryption.
- Edit Boundary variables BOUNDARY_ORGID and BOUNDARY_APIKEY
      - These can be found in Boundary under Configure > Organization
- Edit Pingdom variables PINGDOM_USERNAME, PINGDOM_PASSWORD, and PINGDOM_APPKEY
      - Username and Password are your Pingdom logons
      - AppKey can be found on the Pingdom API Access Page
- Decide on the Polling period
      - Polling Period decides the frequency of checking Pingdom API for new alerts
      - If you plan on scheduling to run the Pingdom-Boundary-Events-Handler periodically, the polling period variable should match the frequency of your scheduled runs

Note:
- This is a demonstration script intended to showcase Boundary's Events API, and how it may work with other products. Your mileage may vary.

For problems email support@boundary.com
     
