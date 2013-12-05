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

BOUNDARY_API_HOST = "api.boundary.com"
ZABBIX_API_HOST = "ZABBIX HOSTNAME or IP"
CACERT_PATH = "#{File.dirname(__FILE__)}/cacert.pem"

# CONFIGURATIONS

BOUNDARY_ORGID = ""
BOUNDARY_APIKEY = ""
ZABBIX_USER = ""
ZABBIX_PASSWORD = ""
POLLING_PERIOD = 60

"""
"""


class BoundaryEvents

  #
  # Some of this code was borrowed from https://github.com/portertech/chef-irc-snitch
  #

  def initialize()
    @boundary_orgid = BOUNDARY_ORGID
    @boundary_apikey = BOUNDARY_APIKEY
    @zabbix_user = ZABBIX_USER
    @zabbix_password = ZABBIX_PASSWORD
    @polling_period = POLLING_PERIOD
 
    now=Time.now
    @past= now - @polling_period
    @past_timestamp = @past.utc.iso8601     # beginning of polling period
    @past_epoch = @past.to_i
    @past_fuc = Time.at(@past).utc
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
		"priority",
                "value" 
	],
        :filter => {
 #	:value => 1
        },
        :sortfield => "priority",
        :sortorder => "DESC",
        :expandData => true,
        :expandComment => true,
        :expandDescription => true,
 #       :lastChangeSince => 0 #  @past
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
        res_json =  JSON.parse(res.body)
	puts res.body
        unless bad_response?(:post, uri.request_uri, res)
          print "Obtained Zabbix Auth Key\n"
          return res_json['result']
        end
      end
    rescue Timeout::Error
      print "Timed out while attempting to authenticate with Zabbix"
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
 
       if lastchange_epoch > @past_epoch  #if the problem is within the polling period
          event = parse_event( description,lastchange_ts,host,comments,triggerid,value)
          events.push(event)
       end
    }
    
    return events
  end

# parse a Zabbix trigger object into a Boundary Events API object
  def parse_event(description,lastchange,host,comments,triggerid,value)
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
          print "Created a Boundary Event @ #{res["location"]}\n"
          res["location"]
        end
      end
    rescue Timeout::Error
      print "Timed out while attempting to create Boundary Event"
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
         print "Got a #{response.code} for #{method} to #{url}" + "\n"
         print response.body + "\n"
    end
  end

  def report
    auth_key = zabbix_login( zabbix_user_login_parse())
    events = zabbix_get_triggers(zabbix_get_triggers_parse(auth_key))
    events.each do |event_body|
      create_event(event_body)
    end
  end



end


boundary_event = BoundaryEvents.new
boundary_event.report
