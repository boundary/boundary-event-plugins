AWS Cloudwatch Boundary Events Handler

Very simple
- Periodically Polls AWS Cloudwatch API for newly-posted alerts
- If alerts are OK or ALERT type, posts them out to Boundary Events Console

Requirements:
- An AWS account (can be IAM) that has been setup for API access through use of a Access Key ID and Secret Access Key. Further, the AWS account must have a policy granting access for the CloudWatch service as defined in its permissions. It will require access to the following CloudWatch actions: "cloudwatch:DescribeAlarmHistory", "cloudwatch:DescribeAlarms", "cloudwatch:DescribeAlarmsForMetric" 
- Ruby 1.9.3 or later ([RVM] (http://rvm.io/rvm/install) is recommended for upgrading where necessary)
- Ruby [gems installer] (http://rubygems.org/pages/download)
- These gems - json, httparty, rsolr

Configuration:
- Be sure to have the cacert.pem file located here: [cacert.pem] (https://github.com/boundary/boundary-event-plugins/tree/master/common), this is required for encryption.
- Edit Boundary variables BOUNDARY_ORGID and BOUNDARY_APIKEY
      - These can be found in Boundary under Configure > Organization
- Edit Amazon EC2 variables ACCESS_KEY_ID and SECRET_KEY
      - Available at http://aws-portal.amazon.com/gp/aws/developer/account/index.html?action=access-key
- Install AWS SDK for Ruby
      - Documentation found at https://aws.amazon.com/sdkforruby/

For help, email support@boundary.com
     
