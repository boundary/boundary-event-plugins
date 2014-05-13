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
require 'time'
require 'base64'
require 'logger'



BOUNDARY_API_HOST = "api.boundary.com"
ZABBIX_API_HOST = "ZABBIX HOSTNAME or IP"
CACERT_PATH = "#{File.dirname(__FILE__)}/cacert.pem"

# CONFIGURATIONS


BOUNDARY_ORGID = ""
BOUNDARY_APIKEY = ""
ZABBIX_USER = ""
ZABBIX_PASSWORD = ""
ZABBIX_TIMEOUT = 30
POLLING_PERIOD = 60
LOGGING_LEVEL = Logger::DEBUG

#
# Controls mapping of Zabbix priority to Boundary event severity
#
SEVERITY_MAP = {}

# Not classified
SEVERITY_MAP[0] = "INFO"
# Information
SEVERITY_MAP[1] = "INFO"
# Warning
SEVERITY_MAP[2] = "WARN"
# Average
SEVERITY_MAP[3] = "ERROR"
# High
SEVERITY_MAP[4] = "ERROR"
# Disaster
SEVERITY_MAP[5] = "CRITICAL"

"""
"""


class BoundaryEvents

  #
  # Some of this code was borrowed from https://github.com/portertech/chef-irc-snitch
  #

  def initialize()
    @logger = Logger.new(STDOUT)
    @logger.level = LOGGING_LEVEL
    @boundary_orgid = BOUNDARY_ORGID
    @boundary_apikey = BOUNDARY_APIKEY
    @zabbix_user = ZABBIX_USER
    @zabbix_password = ZABBIX_PASSWORD
    @polling_period = POLLING_PERIOD
 
    now=Time.now
    @logger.info("Starting")
    @past= now - @polling_period
    @past_timestamp = @past.utc.iso8601     # beginning of polling period
    @past_epoch = @past.to_i
    @past_fuc = Time.at(@past).utc
    @logger.debug("orgid=#{@boundary_orgid}, apikey=#{@boundary_apikey}")
    @logger.debug("polling_period=#{@polling_period}")
    @logger.debug("past: #{@past_func}")
    @logger.debug("zabbix_user: #{@zabbix_user}")
    @logger.debug("Using the following severity mapping: #{SEVERITY_MAP}")
  end

# create a hash to login to Zabbix
  def zabbix_user_login_parse 
    user_obj = {
      :jsonrpc => "2.0",
      :method => "user.login",
      :params => {
         :user => @zabbix_user,
         :password => @zabbix_password
      },
      :id => 1
    }
    return user_obj
  end

# create a hash to request PROBLEM triggers from Zabbix
  def zabbix_get_triggers_parse(auth_key)
    obj = {
      :jsonrpc => "2.0",
      :method => "trigger.get",
      :params => {
	:output => [ 
		"triggerid",
		"description",
                "lastchange", 
		"priority",
                "value" 
	],
      #  :filter => {
      #	:value => 1
      #  },
        :sortfield => "priority",
        :sortorder => "DESC",
        :expandData => true,
        :expandComment => true,
        :expandDescription => true,
        :lastChangeSince => @past_epoch
      },
      :auth => auth_key,
      :id => 1
    }

    return obj
  end

# get zabbix problem triggers, parse the interesting stuff, return in hash form
  def zabbix_get_triggers(obj)
    headers = { "Content-Type" => "application/json"}
    uri = URI( "http://#{ZABBIX_API_HOST}/zabbix/api_jsonrpc.php")
    http = Net::HTTP.new(uri.host, uri.port)

    http.read_timeout = ZABBIX_TIMEOUT
   
    req = Net::HTTP::Post.new(uri.request_uri)
    req.body = obj.to_json
 
    headers.each{ |k,v|
      req[k] = v
    }
    
    res = http.request(req)
    return zabbix_trigger_parse( res.body )
  end

# login to zabbix
  def zabbix_login(auth_obj)
    headers = { "Content-Type" => "application/json"}
    uri = URI( "http://#{ZABBIX_API_HOST}/zabbix/api_jsonrpc.php") 
    http = Net::HTTP.new(uri.host, uri.port)

    auth_key = ""
    
    begin
      timeout(10) do
	req = Net::HTTP::Post.new(uri.request_uri)
        req.body = auth_obj.to_json
        
        headers.each{|k,v|
          req[k] = v
        }

        res = http.request(req)       
        @logger.debug(res)
        res_json =  JSON.parse(res.body)
        unless bad_response?(:post, uri.request_uri, res)
          @logger.debug("Obtained Zabbix Auth Key")
          return res_json['result']
        end
      end
    rescue Timeout::Error
      @logger.error("Timed out while attempting to authenticate with Zabbix")
    end
  end

# parse zabbix trigger messages
  def zabbix_trigger_parse(trigger_obj)
    events = Array.new
    trigger_json = JSON.parse(trigger_obj)
    trigger_json["result"].each { |subresult|
       description = subresult["description"]
       value = subresult["value"]     
       lastchange = subresult["lastchange"]
       lastchange_epoch = lastchange.to_i
       lastchange_ts = DateTime.strptime(lastchange,'%s')
  
       host = subresult["host"]
       comments = subresult["comments"]
       triggerid = subresult["triggerid"]
       priority = subresult["priority"]
 
       if lastchange_epoch > @past_epoch  #if the problem is within the polling period
          event = parse_event(description,lastchange_ts,host,comments,triggerid,value,priority)
          events.push(event)
       end
    }
    
    return events
  end

# Map the Zabbix priority(severity) to the Boundary event severity
  def map_severity(zabbix_severity)
    severity = SEVERITY_MAP[zabbix_severity.to_i]
    if severity == nil
      @logger.error("No mapping of #{zabbix_severity} to a boundary event severity")
    end
    return severity
  end

# parse a Zabbix trigger object into a Boundary Events API object
  def parse_event(description,lastchange,host,comments,triggerid,value,priority)
    severity = map_severity(priority)
    status = "OPEN"

    # Trigger is not in a problem state, set event
    # fields appropriately
    if value.to_i == 0
       status = "CLOSED"
       description = "Zabbix event OK - " + description
       comments = "Zabbix reporting that Event back to OK status" 
    end

    @logger.debug("[#parse_event] creating event => #{value}|#{description}|#{host}|#{status}|#{severity}|#{comments}|#{triggerid}|#{lastchange}")
        
    event = {
       :title => description,
       :tags => ["Zabbix", host],
       :status => status,
       :severity => severity,
       :message => comments,
       :properties => { :triggerid => triggerid },
       :source => { 
	  :ref => host,
          :type => "hostname"
       },
       :sender => {
          :ref => "Zabbix",
          :type => "Zabbix"
       },
       :fingerprintFields => [ "triggerid" ],
       :createdAt => lastchange
    }
    return event
  end

  def create_event(event)
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
          @logger.info("Created a Boundary Event @ #{res["location"]}\n")
          res["location"]
        end
      end
    rescue Timeout::Error
      @logger.error("Timed out while attempting to create Boundary Event")
    end
  end

  def auth_encode(creds)
    Base64.encode64(creds).strip.gsub("\n","")
  end

  def bad_response?(method, url, response)
    case response
    when Net::HTTPSuccess
      false
    else
      true
         @logger.error("Got a #{response.code} for #{method} to #{url}")
         @logger.error(response.body)
    end
  end

  def report
    auth_key = zabbix_login( zabbix_user_login_parse())
    events = zabbix_get_triggers(zabbix_get_triggers_parse(auth_key))
    events.each do |event_body|
      create_event(event_body)
    end
    @logger.info("Finished")
  end

end


boundary_event = BoundaryEvents.new
boundary_event.report

