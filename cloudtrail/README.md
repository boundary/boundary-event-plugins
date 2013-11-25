Boundary’s AWS CloudTrail adapter is a python based script which leverages AWS Boto libraries to poll a specified SQS queue for notifications from CloudTrail that a payload has been generated and then download that payload from the S3 bucket captured within the notification message.


 
As such the adapter requires a few key items to retrieve data from the CloudTrail service, if you need instructions on enabling AWS CloudTrial please reference this quick start KB. This guide captures the instructions for configuring these.

The Boundary CloudTrail adapter and config file can be downloaded and placed in any shared path. For example, /opt/boundary/cloudtrail.


The parameters for the items configured above are set in the [cloudtrail] section of the config file:

tmp-path = /tmp
access-key-id = [AWS Access Key ID]
secret-access-key = [AWS Secret Access Key]
sqs-queue-name = [AWS CloudTrail SQS Queue Name]

tmp-path - controls where CloudTrail payload files are temporarily stored while they’re being processed by the adapter.
 
access-key-id - supplies the AWS Access Key ID that can be used to access the desired AWS environment.
 
secret-access-key - captures the AWS Secret Access Key or password that is used along with the access key id to authenticate with AWS.
 
sqs-queue-name - the name of the queue where CloudTrail SNS notifications are being sent for processing.
 
In addition to the settings for accessing AWS, the adapter requires Boundary authentication information for producing the event data. This information is specified in the [boundary] section of the configuration file:

app-url = https://app.boundary.com
api-url = https://api.boundary.com
org-id = [Boundary ORG ID]
api-key = [Boundary User API Key]

To retrieve your Boundary ORG ID and API Key, while logged int Boundary go to: Organization->Organization Settings

Note that once everything is configured it may take a few minutes to popu
