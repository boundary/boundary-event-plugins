## Boundary Splunk App

Boundary enables customers to monitor and improve application performance. If you have business-critical services deployed in cloud or hybrid IT infrastructures, Boundary can help you ensure these services deliver optimal performance and uptime.

The Boundary app for Splunk feeds information about app topology, latency, and app-to-app conversation information into your Splunk environment. It also allow you to post annotations and alerts based on Splunk search results into Boundary.

Unlike traditional application performance monitoring (APM) solutions, Boundary can monitor all the components that make up an application, regardless of the infrastructure or languages used. The solution automatically builds and updates a logical application topology and makes it fast and easy to identify the location and source of issues and bottlenecks. GitHub, Basho, Canonical, Yammer, Cloudant, and many other customers rely on Boundary solutions every day.

For more information, please visit us at http://boundary.com/.

* * *


## I. Getting Started

First, download and install the Boundary Splunk app by extracting it to a folder called `boundary` in `$SPLUNK_HOME/etc/apps`. Once you've unpacked it, configuring the Boundary Splunk app takes just a second.

### Adding Your Credentials

First, we'll need to grab your Boundary "Organization ID" and API key. You can find your organization ID and API key by logging in at http://app.boundary.com and clicking "Organization » Org Settings" at the top right.

Once you've got it, head to Splunk's App Manager UI and choose the "Set Up" action for the Boundary app. Then, drop the API Key and Organizaton ID into the form and click Save.


### And you're done!

With your configuration set and Splunk restarted, you're good to go!

For support, please contact support@boundary.com.

 

* * *

 

## II. Now, what can I do with it?

#### 1. Post Annotations to Boundary from Splunk

The Boundary Splunk App allows you to post annotations from Splunk search results on Boundary graphs. To post an annotation to Boundary from a Splunk search, click the drop-down next to the result and choose "Boundary Annotation."

The annotation will appear in your streaming Boundary dashboard live.


* * *

 

#### 2. Trigger Automatic Boundary Annotations based on Splunk Searches

The app also allows you to stream Annotations to Boundary based on logs that appear in Splunk searches automatically in the background. It's a great way to post "error" or other critical information to Boundary.

These are configured via "Searches and Reports" in Splunk Manager as scheduled searches that pass output to the Boundary app. We recommend configuring them to run every five minutes over the past five minutes of history. Click the screenshot below to see how they're set up.
 

* * *

 

#### 3. Mix App Topology Data from Boundary into Splunk Searches

This integration allows you to fetch the IP or operating system running on a host, along with a list of all applications on these hosts, as attributes on a search. With this powerful extension to Splunk's query language, you can compose searches that search for logs pertaining to host-to-host or app-to-app traffic when diagnosing problems in your systems.

1.  **Get the application names:**  
    This is the easiest use case. In order to get the application names for a particular host, simply run a search and append: 

         <search> | lookup host_to_app_map host
    
      
    The app names associated with that host will appear in a field called app_names. This field contains comma separated values of application names which are associated with that host. In order to make this into a Splunk multi-value field:  
      
        <search> | lookup host_to_app_map host | eval app_names_mv=split(app_names, ",")
    
      
    This will place the app names into a new field called app\_names\_mv.  
      
    
2.  **Get the IP or operating system associated with a host:**  
    IP addresses are in a different lookup table called meter_info. This is also a very simple lookup:  

        <search> | lookup meter_info host This will return info into two new fields for your use, export_ip and os.

* * *


#### 4. Load the Boundary AppVis view inside Splunk

The app also adds the Boundary AppVis view as a tab in Splunk. Just click the "Boundary AppVis" tab above to pull it up.
 

* * *

For support, please contact support@boundary.com. Happy Splunking!
