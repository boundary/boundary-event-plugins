require 'rubygems'
require 'aws-sdk'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'httparty'



##############################################################
# USER CONFIGURATION
######

BOUNDARY_ORGID = ""
BOUNDARY_APIKEY = ""
ACCESS_KEY_ID = ''
SECRET_KEY = ''

###############################################################

BOUNDARY_API_HOST = "api.boundary.com"
CACERT_PATH = "#{File.dirname(__FILE__)}/../common/cacert.pem"


###############################################################

class BoundaryEvents
   
   def initialize	
      @access_key_id = ACCESS_KEY_ID
      @secret_key = SECRET_KEY
      @boundary_orgid = BOUNDARY_ORGID
      @boundary_apikey = BOUNDARY_APIKEY
      
      AWS.config({
  	    :access_key_id => @access_key_id,
            :secret_access_key => @secret_key
      })
   end

   def poll_aws
      cw = AWS::CloudWatch.new
      new_events = Array.new

      cw.alarms.each { |m|
         if m.state_value == "ALARM" or m.state_value == "OK"
            evt = event_parse(m)
            new_events.push(evt)
         end
      }
      return new_events
   end

   def report
      events = poll_aws
      events.each do |event_body|
         create_event(event_body)
      end
   end

   def event_parse(m)
      instance = ""
      severity = "ERROR"
      status = "OPEN"
      if m.state_value == "ALARM"
         severity = "ERROR"
         status = "OPEN"
      else
         severity = "INFO"
         status = "CLOSED"
      end
      m.dimensions.each { |d| 
         d.each    { |dimension,value|
              if dimension.to_s == "value"
                  instance = value.to_s
              end
         }
      }
      event = {
          :title => "Cloudwatch " + m.state_value + " - " + m.metric_name ,
          :tags => ["Cloudwatch", m.namespace , m.metric_name] ,
          :status => status,
          :severity => severity,
          :message => m.state_reason,
          :source => {
              :ref => instance,
              :type => "ec2",
          },
          :sender => {
              :ref => "CloudWatch",
              :type => "Cloudwatch"
          },
          :properties => {
              :eventKey => "Cloudwatch-alert",
              :sender => "Cloudwatch",
              :source => instance
          },
          :fingerprintFields => [ "source","sender" ]
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

end        

boundary_event = BoundaryEvents.new
boundary_event.report

