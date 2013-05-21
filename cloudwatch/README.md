AWS Cloudwatch Boundary Events Handler

Very simple
- Periodically Polls AWS Cloudwatch API for newly-posted alerts
- If alerts are OK or ALERT type, posts them out to Boundary Events Console

Configuration:
1. Be sure to have the cacert.pem file, this is required for encryption.
2. Edit Boundary variables BOUNDARY_ORGID and BOUNDARY_APIKEY
      - These can be found in Boundary under Configure > Organization
3. Edit Amazon EC2 variables ACCESS_KEY_ID and SECRET_KEY
      - Available at http://aws-portal.amazon.com/gp/aws/developer/account/index.html?action=access-key
4. Install AWS SDK for Ruby
      - Documentation found at https://aws.amazon.com/sdkforruby/

Note:
- This is a demonstration script intended to showcase Boundary's Events API, and how it may work with other products. Your mileage may vary.

For problems email support@boundary.com
     
