#!/usr/bin/env ruby

#
# Copyright 2013-2014, Boundary
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rubygems'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'httparty'
require 'rsolr'
require 'logger'


module TRIGGER_VALUE
  OK = 0
  PROBLEM = 1
end

#
# Certificate
# NOTE: it is assumed that the cert is in the same directory as this script file
CACERT_PATH = "#{File.dirname(__FILE__)}/cacert.pem"

# Public: Encapsulation of the Boundary API and Zabbix API to inject the status of Zabbix
#         triggers via events into Boundary.
#
class BoundaryEvents
  
  attr_reader :boundary_orgid, :boundary_apikey, :zabbix_user, :zabbix_password, :polling_window, :lastChangeSince

  # Public: Constructor for BoundaryEvent class
  #
  # NOTE: Organizational ID and API key can be obtained from https://app.boundary.com/account
  #       Contact service@boundary.com to obtain an organizational and API key
  #
  # orgid - Boundary organizational id.
  # apikey - Boundary API key.
  # user - User name to use for authorization against the Zabbix server
  # password - Password to user for authorization against the Zabbix server
  # apihost - Boundary API host, default to api.boundary.com
  # logginglevel - Logging level setting, defaults to Logger::WARN
  # window - How far back in time (in seconds) to query for the status of triggers within the Zabbix server
  #
  def initialize(orgid,apikey,user,password,zabbixHost="localhost",apihost="api.boundary.com",logginglevel=Logger::DEBUG,window=300)
    @organizationID = orgid
    @apiKey = apikey
    @apiHost = apihost
    
    @zabbixUser = user
    @zabbixPassword = password
    @zabbixHost = zabbixHost
    
    @pollingWindow = window
    
    # Configure our logger
    @log = Logger.new(STDOUT)
    @log.level = logginglevel
    
    @zabbixServerTimeout = 10
    @boundaryServerTimeout = 10

    @lastChangeSince = (Time.now - @pollingWindow).to_i()
    
    @log.debug("lastChangeSince: #{@lastChangeSince}, #{Time.at(@lastChangeSince)}")
    
    @triggerCount = 0

  end
  
  # Internal: Logs the entry into a function or method call
  #
  # function  - Name of the function that is being entered, usually set to __method__ by caller
  #
  #   def foo()
  #     enter(__method__)
  #   end
  #
  # Returns nil
  def enter(function)
    @log.debug("#{function}()")
  end
  
  # Internal: Creates the JSON RPC hash for authorization call to Zabbix server
  #
  #
  # Examples
  #
  #   q = zabbic_user_login_parse()
  #
  # Returns hash of JSON RPC hash to request an authorization token
  def zabbix_user_login_parse()
    enter(__method__)
    user_obj = {
      :jsonrpc => "2.0",
      :method => "user.login",
      :params => {
      :user => @zabbixUser,
      :password => @zabbixPassword
      },
      :id => 1
    }
    @log.debug("user_obj: #{user_obj}")
    return user_obj
  end

  # Internal: Creates the JSON RPC hash for querying triggers on the Zabbix server
  #
  # auth_key - Authorization key
  #
  # Examples
  #
  #   q = zabbix_get_triggers_parse()
  #
  # Returns hash of JSON RPC hash to query for triggers.
  def zabbix_get_triggers_parse(auth_key)
    enter(__method__)
    obj = {
      :jsonrpc => "2.0",
      :method => "trigger.get",
      :params => { :output => ["triggerid","description","priority","lastchange","value"],
                   :filter => {#	:value => 1
                    },
                   :sortfield => "priority",
                   :sortorder => "DESC",
                   :expandData => true,
                   :expandComment => true,
                   :expandDescription => true,
                   :lastChangeSince => @lastChangeSince
                 },
      :auth => auth_key,
      :id => 1
    }
    @log.debug("obj: #{obj}")
    return obj
  end

  # Internal: Query the Zabbix server via JSON RPC to fetch the problematic triggers
  #
  # obj - JSON RPC hash user to query for triggers
  #
  # Examples
  #
  #   q = zabbix_get_triggers_parse()
  #
  # Returns hash of trigger objects from request to Zabbix server
  def zabbix_get_triggers(obj)
    enter(__method__)
    
    # Create hash which will become the HTTP header describing the payload of the request
    headers = { "Content-Type" => "application/json"}
      
    # Form the URI to the Zabbix REST API
    uri = URI( "http://#{@zabbixHost}/zabbix/api_jsonrpc.php")
    
    # Create HTTP object that will handle sending the REST call to the Zabbix server
    http = Net::HTTP.new(uri.host, uri.port)
   
    # Create a post request to be issued against the Zabbix server
    req = Net::HTTP::Post.new(uri.request_uri)
   
    # Set the HTTP request payload with JSON object
    req.body = obj.to_json
    
    # Assign the HTTP headers to the HTTP request
    headers.each{ |k,v| req[k] = v }

    # Issue the REST call to the Zabbix server
    # TODO: Error checking??, exception thrown, etc?
    res = http.request(req)
    
    # Parse the output and return hash representation of the trigger objects
    return zabbix_trigger_parse(res.body)
  end

  # Internal: Execute JSON RPC call against the Zabbix server to get our authorization string.
  #
  # auth_obj - Zabbix authorization token
  #
  # Examples
  #
  #   zabbix_login(auth_obj)
  # 
  # Returns nil
  def zabbix_login(auth_obj)
    enter(__method__)
    
    # Define HTTP header the indicate the type of payload in the REST call.
    headers = { "Content-Type" => "application/json"}
      
    # Form URI to make the call to the Zabbix API
    uri = URI("http://#{@zabbixHost}/zabbix/api_jsonrpc.php") 
    http = Net::HTTP.new(uri.host, uri.port)
    auth_key = ""
    
    begin
      timeout(@zabbixServerTimeout) do
      req = Net::HTTP::Post.new(uri.request_uri)
      req.body = auth_obj.to_json
        
      headers.each{ |k,v| req[k] = v }

      res = http.request(req)       
      res_json =  JSON.parse(res.body)
      @log.debug("res.body: #{res.body}")
      unless bad_response?(:post, uri.request_uri, res)
        @log.info("Obtained Zabbix Auth Key")
        return res_json['result']
      end
    end
    rescue Timeout::Error
      @log.error("Timed out while attempting to authenticate with Zabbix")
    end
  end
  

  # Internal: Parse the JSON response from the call to the active triggers in the Zabbix server
  #
  # trigger_obj - Hash containing the results of the query to the Zabbix host for triggers.
  #
  # Examples
  #
  #   zabbix_login(auth_obj)
  #
  # Returns nil

  def zabbix_trigger_parse(trigger_obj)
    enter(__method__)
    @triggerCount = 0
    events = Array.new
    @log.debug("trigger_obj: #{trigger_obj}")
    trigger_json = JSON.parse(trigger_obj)
    trigger_json["result"].each do |subresult|
      description = subresult["description"]
      value = subresult["value"]
      lastchange = subresult["lastchange"]
      lastchange_epoch = lastchange.to_i
      lastchange_ts = DateTime.strptime(lastchange,'%s')

      host = subresult["host"]
      comments = subresult["comments"]
      triggerid = subresult["triggerid"]

      @log.debug("description: #{description}, lastchange_ts: #{lastchange_ts}, host: #{host}, triggerid: #{triggerid}, value: #{value}")
      event = parseEvent( description,lastchange_ts,host,comments,triggerid,value)
      events.push(event)
      
      # Increment our processed trigger count for later reporting
      @triggerCount += 1
    end

    return events
  end

  # Internal: parse a Zabbix trigger object into a Boundary Events API object
  #
  # description  - Name of the trigger
  # lastchange - The Integer number of times to duplicate the text.
  # host - Hostname associated with the Zabbix trigger
  # comments - Additional comments on the trigger
  # triggerid - Unique id of the Zabbix trigger
  # value - Status of the trigger Possible values are: 0 - (default) OK, 1 - problem.
  #
  # Examples
  #
  #   parseEvent(description,lastChange,host,comments,triggerID,value)
  #
  # Returns the event hash
  def parseEvent(description,lastchange,host,comments,triggerid,value)
    enter(__method__)
    severity = "ERROR"
    status = "OPEN"
 
    if value == TRIGGER_VALUE::OK
       severity = "INFO"
       status = "CLOSED"
       description = "Zabbix event OK - " + description
       comments = "Zabbix reporting that Event back to OK status" 
    end
        
    event = {
       :title => description,
       :tags => ["Zabbix", host],
       :status => status,
       :severity => severity,
       :message => comments,
       :properties => { :triggerid => triggerid },
       :source => { :ref => host,:type => "hostname" },
       :sender => { :ref => "Zabbix",:type => "Zabbix" },
       :fingerprintFields => ["triggerid"],
       :createdAt => lastchange
    }
    
    @log.debug("event: #{event}")
    return event
  end

  # Internal: Creates or updates an event on the Boundary server
  #
  # event  - event in the form of a hash to create or update
  #
  # Returns nil
  def createEvent(event)
    enter(__method__)
    
    # Encode our Basic authentication token
    auth = auth_encode("#{@apiKey}:")
    @log.debug("auth: #{auth}")
    
    # Add the HTTP header identifying the payload as JSON
    headers = {"Authorization" => "Basic #{auth}", "Content-Type" => "application/json"}
      
    # Form the URI to send an event to Boundary
    uri = URI("https://#{@apiHost}/#{@organizationID}/events")
    @log.debug("uri: #{uri}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = CACERT_PATH
    @log.debug("http.ca_file: #{http.ca_file}")
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    begin
      timeout(@boundaryServerTimeout) do
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = event.to_json

        headers.each{ |k,v| req[k] = v }

        res = http.request(req)

        unless bad_response?(:post, uri.request_uri, res)
          @log.info("Created a Boundary Event @ #{res["location"]}")
          res["location"]
        end
      end
    rescue Timeout::Error
      @log.error("Timed out while attempting to create Boundary Event")
    end
  end
  
  # Internal: Base64 encode authorization string
  #
  # creds  - String consisting of <user>:<password>
  #
  # Examples
  #
  #   auth_encode('foo:bar')
  #   => "Zm9vOmJhcg=="
  #
  # Returns Base64 encoded user/password string
  def auth_encode(creds)
    enter(__method__)
    Base64.encode64(creds).strip.gsub("\n","")
  end

  # Internal: Base64 encode authorization string
  #
  #
  # Returns false, HTTP request was successful or true, HTTP request failed
  def bad_response?(method, url, response)
    enter(__method__)
    case response
    when Net::HTTPSuccess
      false
    else
      true
      @log.info("Got a #{response.code} for #{method} to #{url}")
      @log.debug("response.body: #{response.body}")
    end
  end

  # Public: Main method that handles communicating with the Boundary and Zabbix servers
  #         using their respect APIs
  #
  # Examples
  #
  #   e = BoundaryEvent.new("<boundary organization id>","<boundary API key>","<zabbix user>","<zabbix password>")
  #   e.processEvents()
  #
  # Returns nil
  def processEvents()
    enter(__method__)
    auth_key = zabbix_login(zabbix_user_login_parse())
    events = zabbix_get_triggers(zabbix_get_triggers_parse(auth_key))
    events.each do |event_body|
      @log.info("calling create_event with: #{event_body}")
      createEvent(event_body)
    end
    
    @log.info("Processed #{@triggerCount} trigger(s)")
  end
  
end

#
# Configuration values
#
BOUNDARY_ORGID = '<Your Organization ID Here>'
BOUNDARY_APIKEY = '<Your API Key Here>'
BOUNDARY_HOST = "api.boundary.com"
ZABBIX_USER = "Admin"
ZABBIX_PASSWORD = "zabbix"
ZABBIX_HOST = "192.168.128.130"
LOGGING_LEVEL = Logger::WARN
WINDOW = 60 * 60 * 24 * 7 # Query back the last seven days

# Create a new instance of a Boundary Event and invoke method to process events.
boundary_event = BoundaryEvents.new(BOUNDARY_ORGID,
                                    BOUNDARY_APIKEY,
                                    ZABBIX_USER,
                                    ZABBIX_PASSWORD,
                                    ZABBIX_HOST,
                                    BOUNDARY_HOST,
                                    LOGGING_LEVEL,
                                    WINDOW)
boundary_event.processEvents()
