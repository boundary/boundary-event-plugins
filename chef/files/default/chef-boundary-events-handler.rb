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
require 'chef'
require 'chef/handler'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

class BoundaryEvents < Chef::Handler

  #
  # Some of this code was borrowed from https://github.com/portertech/chef-irc-snitch
  #

  def initialize(options)
    @boundary_orgid = options[:orgid]
    @boundary_apikey = options[:apikey]
  end

  def success_event
    {
      :title => "Successful Chef run",
      :tags => ["chef-success"],
      :status => "CLOSED",
      :severity => "INFO",
      :message => "Successful Chef run for #{run_status.node.name} (#{run_status.node.ipaddress})",
      :properties => {
        :updatedResourceCount => run_status.updated_resources.length.to_i,
      }
    }
  end

  def failed_event
    {
      :title => "Failed Chef run",
      :tags => ["chef-failure"],
      :status => "OPEN",
      :severity => "ERROR",
      :message => "Failed Chef run for #{run_status.node.name} (#{run_status.node.ipaddress})",
      :properties => {
        :exception => run_status.formatted_exception,
        :backtrace => backtrace
      }
    }
  end

  def report
    if run_status.success?
      event_body = success_event
      Chef::Log.info("Chef run suceeded with #{run_status.updated_resources.length.to_i} changes @ #{run_status.end_time}; creating Boundary Event")
    elsif run_status.failed?
      event_body = failed_event
      Chef::Log.error("Chef run failed @ #{run_status.end_time}, creating Boundary Event")
      Chef::Log.error("#{run_status.formatted_exception}")
    end

    event_body[:properties].update({:run_list=>run_status.node.run_list, :roles=>run_status.node.roles})
    create_event(event_body)
  end

  def create_event(event)
    auth = auth_encode("#{@boundary_apikey}:")
    headers = {"Authorization" => "Basic #{auth}", "Content-Type" => "application/json"}

    event.update({
      :organizationId => @boundary_orgid,
      :source => {
        :ref => run_status.node.name,
        :type => "host"
      }
    })

    event[:fingerprintFields] ||= []
    event[:fingerprintFields] << "eventKey"
    event[:properties].update({
      :eventKey => "chef-run",
      :startTime => run_status.start_time.to_i,
      :endTime => run_status.end_time.to_i,
    })

    uri = URI("https://api.boundary.com/#{@boundary_orgid}/events")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = "#{File.dirname(__FILE__)}/boundary-cacert.pem"
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
          Chef::Log.info("Created a Boundary Event @ #{res["location"]}")
          res["location"]
        end
      end
    rescue Timeout::Error
      Chef::Log.error("Timed out while attempting to create Boundary Event")
    end
  end

  def auth_encode(creds)
    auth = Base64.encode64(creds).strip.gsub("\n", "")
  end

  def bad_response?(method, url, response)
    case response
    when Net::HTTPSuccess
      false
    else
      true
      Chef::Log.error("Got a #{response.code} for #{method} to #{url}")
      Chef::Log.error(response.body)
    end
  end

end
