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

require "rubygems"
require "base64"
require "json"
require "net/http"
require "net/https"
require "optparse"
require "uri"
require "yaml"

$stdout.reopen("#{File.dirname(__FILE__)}/boundary-out.txt", "w")
$stderr.reopen("#{File.dirname(__FILE__)}/boundary-err.txt", "w")

BOUNDARY_API_HOST = "api.boundary.com"
BOUNDARY_CONFIG_PATH = "/etc/icinga/boundary.yml"
CACERT_PATH = "#{File.dirname(__FILE__)}/../common/cacert.pem"

def load_config(path)
  begin
    config = YAML.load_file(path)
  rescue
    return {}
  end

  if config.key?("apikey") && config.key?("orgid")
    return config
  else
    return {}
  end
end

class BoundaryEvent
  def initialize(options)
    @orgid = options[:orgid]
    @apikey = options[:apikey]
  end

  def create_event(data)
    ok_states = ["OK", "UP"]

    @data = {
      :title => "Icinga #{data[:event_type].to_s} event",
      :tags => ["icinga"],
      :status => "OPEN",
      :severity => data[:state],
      :message => data[:output].split("\n")[0],
      :properties => {
        :eventKey => "icinga-check",
        :state => data[:state],
        :stateType => data[:state_type].to_s,
        :attempts => data[:attempts],
        :output => data[:output]
      },
      :organizationId => @orgid,
      :source => {
        :ref => data[:hostname],
        :type => "host"
      },
      :sender => {
        :ref => data[:sender_hostname],
        :type => "icinga"
      },
      :fingerprintFields => ["eventKey"],
    }
  end

  def handle
    auth = auth_encode("#{@apikey}:")
    headers = {
      "Authorization" => "Basic #{auth}",
      "Content-Type" => "application/json"
    }

    uri = URI("https://#{BOUNDARY_API_HOST}/#{@orgid}/events")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = CACERT_PATH
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    begin
      timeout(10) do
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = @data.to_json

        headers.each{|k,v|
          req[k] = v
        }

        res = http.request(req)

        if res.kind_of?(Net::HTTPSuccess)
          puts "Created a Boundary Event @ #{res["location"]}"
        else
          $stderr.print "Request to #{uri.request_uri} responded with HTTP #{res.code}\n"
          $stderr.print "#{res.body}\n"
        end
      end
    rescue Timeout::Error
      $stderr.print "Timed out while attempting to create Boundary Event\n"
    end
  end

  def auth_encode(creds)
    auth = Base64.encode64(creds).strip
    auth.gsub("\n","")
  end
end

options = {}

options[:config] = BOUNDARY_CONFIG_PATH

OptionParser.new do |opts|
  opts.on("-c", "--config CONFIG", "Config file") { |c| options[:config] = c }
  opts.on("-H", "--hostname HOSTNAME", "Hostname") { |h| options[:hostname] = h }
  opts.on("-e", "--event-type TYPE", [:host, :service], "Event type") { |e| options[:event_type] = e }
  opts.on("-s", "--state STATE", "Event state") { |s| options[:state] = s }
  opts.on("-t", "--state-type TYPE", [:HARD, :SOFT], "Event state type") { |t| options[:state_type] = t }
  opts.on("-a", "--attempts ATTEMPTS", OptionParser::DecimalInteger, "Event attempts") { |a| options[:attempts] = a }
  opts.on("-o", "--output OUTPUT", "Check output") { |o| options[:output] = o }
  opts.on("-d", "--description DESC", "Service description") { |d| options[:service_description] = d }
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

  begin
    opts.parse!

    # these are required flags
    required = [:event_type, :hostname, :state, :state_type, :attempts, :output]
    missing = required.select { |f| options[f].nil? }
    unless missing.empty?
      raise OptionParser::ParseError, "Missing flag(s): " + missing.collect{|o| "--" + o.to_s.gsub(/_/, "-")}.join(" ")
    end

    if options[:event_type] == "service"
      if options[:description].nil?
        raise OptionParser::ParseError, "Missing flag(s): --description"
      end
    else
      options[:description] = nil
    end
  rescue OptionParser::ParseError
    $stderr.print "Error: #{$!}\n"

    puts
    puts opts
    exit 1
  end
end

config = load_config(options[:config])
data = options.merge({:sender_hostname => config["sender"]})

event = BoundaryEvent.new({:orgid => config["orgid"], :apikey => config["apikey"]})
event.create_event(data)
event.handle
