Boundary’s AWS CloudTrail adapter is a Python script which leverages the AWS Boto libraries to poll a specified SQS queue for notifications from CloudTrail that a payload has been generated and then download that payload from the S3 bucket captured within the notification message.

As such the adapter requires a few key items to retrieve data from the CloudTrail service, if you need instructions on enabling AWS CloudTrail please reference [this quick start KB](http://support.boundary.com/customer/portal/articles/1370167-configuring-amazon-cloudtrail-for-the-boundary-cloudtrail-adapter). This guide captures the instructions for configuring these.

The Boundary CloudTrail adapter and config file can be downloaded and placed in any shared path. For example, /opt/boundary/cloudtrail.

The parameters for the items configured above are set in the [cloudtrail] section of the config file:

```
tmp-path = /tmp
access-key-id = [AWS Access Key ID]
secret-access-key = [AWS Secret Access Key]
sqs-queue-name = [AWS CloudTrail SQS Queue Name]
```

**tmp-path**
* Controls where CloudTrail payload files are temporarily stored while they’re being processed by the adapter.
 
**access-key-id**
* Supplies the AWS Access Key ID that can be used to access the desired AWS environment. This can be the id to a specific user (IAM or otherwise) that has been setup for the adapter or a pre-existing account. In either case, the account will need "read" privelages to SQS, S3 the access policy below can be applied to the user record to establish the necessary permissions.

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1392930026000",
      "Effect": "Allow",
      "Action": [
        "sqs:*"
      ],
      "Resource": [
        "INSERT SQS ARN HERE"
      ]
    },
    {
      "Sid": "Stmt1392930466000",
      "Effect": "Allow",
      "Action": [
        "sqs:ListQueues"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "Stmt1392930063000",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "INSERT S3 ARN HERE"
      ]
    },
    {
      "Sid": "Stmt1392930914000",
      "Effect": "Allow",
      "Action": [
        "s3:List*",
        "s3:Get*"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "Stmt1392930305000",
      "Effect": "Allow",
      "Action": [
        "sns:*"
      ],
      "Resource": [
        "INSERT SNS ARN HERE"
      ]
    }
  ]
}
```
 
**secret-access-key**
* Captures the AWS Secret Access Key or password that is used along with the access key id to authenticate with AWS.

**sqs-queue-name**
* The name of the queue where CloudTrail SNS notifications are being sent for processing.
 
In addition to the settings for accessing AWS, the adapter requires Boundary authentication information for producing the event data. This information is specified in the [boundary] section of the configuration file:

```
app-url = https://app.boundary.com
api-url = https://api.boundary.com
org-id = [Boundary ORG ID]
api-key = [Boundary User API Key]
```

To retrieve your Boundary ORG ID and API Key, while logged in to Boundary go to: Organization->Organization Settings

Note that once everything is configured it may take a few minutes to populate the Boundary Events Console as Amazon CloudTrail operates on five-minute intervals.
