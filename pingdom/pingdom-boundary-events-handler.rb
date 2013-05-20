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

BOUNDARY_API_HOST = "api.boundary.com"
PINGDOM_API_HOST = "api.pingdom.com"
CACERT_PATH = "#{File.dirname(__FILE__)}/../common/cacert.pem"

class BoundaryEvents

  #
  # Some of this code was borrowed from https://github.com/portertech/chef-irc-snitch
  #

  def initialize(options)
    @boundary_orgid = options[:orgid]
    @boundary_apikey = options[:apikey]
    @pingdom_username = options[:username]
    @pingdom_password = options[:password]
    @pingdom_appkey = options[:appkey]
    @polling_period = options[:pollingperiod]
    @epoch = Time.now.to_i - @polling_period # here we poll once a minute, so we take EPOCH minus 60 seconds as beginning of our polling period

  end

  def poll_pingdom_alerts
    uri = "http://#{PINGDOM_API_HOST}/api/2.0/checks"
    auth = {:username => @pingdom_username, :password => @pingdom_password}
    headers = {"App-Key" => @pingdom_appkey , 'ContentType' => 'application/json'}
    response = HTTParty.get(uri, :basic_auth => auth, :headers => headers)
    myjson =  JSON.parse(response.body)
    new_events = Array.new
    myjson["checks"].each do |check|
      check_time = check["created"].to_i
      if check_time > @epoch   # check if this is a fresh alert
        evt = event_parse(check)
        new_events.push(evt)
      end
    end

    return new_events
  end

  def event_parse(check)
    #not sure what to use here.. different pingdom statuses are "up","down","unconfirmed_down","unknown","paused"
    #so we may need to adjust status and severity accordingly
    event = {
      :title => "Pingdom Check Failure",
      :tags => ["pingdom-failure"],
      :status => "OPEN",
      :severity => "ERROR",
      :message => "Pingdom Check for " + check["name"] + " | status=" + check["status"],
      :source => {
        :ref => check["hostname"],
        :type => "Pingdom"
      },
      :properties => {
        :eventKey => "Pingdom-check",
        :starttime => check["lasttesttime"]
      },
      :fingerprintFields => ["eventKey"]
    }

    return event
  end


  def report
    events = poll_pingdom_alerts
    events.each do |event_body|
      create_event(event_body)
    end
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
      Chef::Log.error("Timed out while attempting to create Boundary Event")
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

end
