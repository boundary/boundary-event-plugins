#!/usr/bin/env ruby

#
# Copyright 2013, Boundary
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

BOUNDARY_API_HOST = "api.boundary.com"
#ZABBIX_API_HOST = "ZABBIX HOSTNAME or IP"
ZABBIX_API_HOST = "192.168.1.115"
CACERT_PATH = "#{File.dirname(__FILE__)}/cacert.pem"

# CONFIGURATIONS

BOUNDARY_ORGID = "3ehRi7uZeeaTN12dErF5XOnRXjC"
BOUNDARY_APIKEY = "ARI0PzUzWYUo7GG1OxiHmABTpr9"
ZABBIX_USER = "Admin"
ZABBIX_PASSWORD = "zabbix"
POLLING_PERIOD = 60

class BoundaryEvents

  # Public: Initialize a Widget.
  #
  # name - A String naming the widget.
  def initialize()
    #print "intialize()\n"
    @boundary_orgid = BOUNDARY_ORGID
    @boundary_apikey = BOUNDARY_APIKEY
    @zabbix_user = ZABBIX_USER
    @zabbix_password = ZABBIX_PASSWORD
    @polling_period = POLLING_PERIOD
    
    @last_trigger_time = 0
 
    now=Time.now
    @past= now - @polling_period
    @past_timestamp = @past.utc.iso8601     # beginning of polling period
    @past_epoch = @past.to_i
    @past_fuc = Time.at(@past).utc
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @log.debug("now: #{now}, past_timestamp: #{@past_time}, past_epoch: #{@past_epoch}, past_fuc: #{@past_fuc}")
  end
  
  def enter(function)
    @log.info("#{function}()")
  end

# create a hash to login to Zabbix
  def zabbix_user_login_parse
    enter(__method__)
    user_obj = {
      :jsonrpc => "2.0",
      :method => "user.login",
      :params => {
      :user => @zabbix_user,
      :password => @zabbix_password
      },
      :id => 1
    }
    @log.debug("user_obj: #{user_obj}")
    return user_obj
  end

  # create a hash to request PROBLEM triggers from Zabbix
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
                   :lastChangeSince => @past
                 },
      :auth => auth_key,
      :id => 1
    }
    @log.debug("obj: #{obj}")
    return obj
  end

# get zabbix problem triggers, parse the interesting stuff, return in hash form
  def zabbix_get_triggers(obj)
    enter(__method__)
    
    # Create hash which will become the HTTP header describing the payload of the request
    headers = { "Content-Type" => "application/json"}
      
    # Form the URI to the Zabbix REST API
    uri = URI( "http://#{ZABBIX_API_HOST}/zabbix/api_jsonrpc.php")
    
    # Create HTTP object that will handle sending the REST call to the Zabbix server
    http = Net::HTTP.new(uri.host, uri.port)
   
    # Create a post request to be issued against the Zabbix server
    req = Net::HTTP::Post.new(uri.request_uri)
   
    # Set the HTTP request paylod with JSON object
    req.body = obj.to_json
    
    # Assign the HTTP headers to the HTTP request
    headers.each{ |k,v|
      req[k] = v
    }

    # Issue the REST call to the Zabbix server
    # TODO: What expections does this
    res = http.request(req)
    return zabbix_trigger_parse( res.body )
  end

# login to zabbix
  def zabbix_login(auth_obj)
    enter(__method__)
    headers = { "Content-Type" => "application/json"}
    uri = URI( "http://#{ZABBIX_API_HOST}/zabbix/api_jsonrpc.php") 
    http = Net::HTTP.new(uri.host, uri.port)

    auth_key = ""
    
    begin
      timeout(10) do
      req = Net::HTTP::Post.new(uri.request_uri)
      req.body = auth_obj.to_json
        
      headers.each{ |k,v| req[k] = v }

      res = http.request(req)       
      res_json =  JSON.parse(res.body)
      puts res.body
      unless bad_response?(:post, uri.request_uri, res)
        @log.info("Obtained Zabbix Auth Key")
        return res_json['result']
      end
    end
    rescue Timeout::Error
      @log.error("Timed out while attempting to authenticate with Zabbix")
    end
  end
  

# parse zabbix trigger messages
  def zabbix_trigger_parse(trigger_obj)
    enter(__method__)
    events = Array.new
    @log.debug("trigger_obj: #{trigger_obj}")
    trigger_json = JSON.parse(trigger_obj)
    trigger_json["result"].each do |subresult|
       
       description = subresult["description"]
       @log.debug("description: #{description}")
       value = subresult["value"]     
       lastchange = subresult["lastchange"]
       @log.debug("lastchange: #{lastchange}")
       lastchange_epoch = lastchange.to_i
       lastchange_ts = DateTime.strptime(lastchange,'%s')
       @log.debug("lastchange_ts: #{lastchange_ts}")
  
       host = subresult["host"]
       comments = subresult["comments"]
       triggerid = subresult["triggerid"]
 
       if lastchange_epoch > @past_epoch  #if the problem is within the polling period
          @log.debug("description: #{description}, lastchange_ts: #{lastchange_ts}, host: #{host}, triggerid: #{trigger_id}, value: #{value}")
          event = parse_event( description,lastchange_ts,host,comments,triggerid,value)
          events.push(event)
       end
    end
 
    return events
  end

  # Internal: parse a Zabbix trigger object into a Boundary Events API object
  #
  # description  - Description of the Zabbix trigger
  # lastchange - The Integer number of times to duplicate the text.
  # host - Hostname associated with the Zabbix trigger
  # comments - 
  # trigger - Unique id of the Zabbix trigger
  # value -
  #
  # Examples
  #
  #   multiplex('Tom', 4)
  #   # => 'TomTomTomTom'
  #
  # Returns the event hash
  def parse_event(description,lastchange,host,comments,triggerid,value)
    enter(__method__)
    severity = "ERROR"
    status = "OPEN"
 
    if value == 0
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

  def create_event(event)
    enter(__method__)
    auth = auth_encode("#{@boundary_apikey}:")
    headers = {"Authorization" => "Basic #{auth}", "Content-Type" => "application/json"}
    uri = URI("https://#{BOUNDARY_API_HOST}/#{@boundary_orgid}/events")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = CACERT_PATH
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    begin
      timeout(10) do
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = event.to_json

        headers.each{|k,v|
          req[k] = v
        }

        res = http.request(req)

        unless bad_response?(:post, uri.request_uri, res)
          @log.info("Created a Boundary Event @ #{res["location"]}")
          res["location"]
        end
      end
    rescue Timeout::Error
      print "Timed out while attempting to create Boundary Event\n"
    end
  end
  
  # Internal: Base64 encode authorization string
  #
  # creds  - String consiting of <user>:<password>
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

  def report
    enter(__method__)
    auth_key = zabbix_login( zabbix_user_login_parse())
    events = zabbix_get_triggers(zabbix_get_triggers_parse(auth_key))
    events.each do |event_body|
      @log.info("calling create_event: #{event_body}")
      create_event(event_body)
    end
  end
  
end

boundary_event = BoundaryEvents.new
boundary_event.report
