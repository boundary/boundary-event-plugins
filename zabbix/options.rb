#!/usr/bin/env ruby
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'
require 'logger'


# The options specified on the command line will be collected in *options*.
# We set default values here.
#options = OpenStruct.new
#options.organizationID = nil
#options.apiKey = nil
#options.apiHost = "api.boundary.com"
#options.apiHostTimeout = 10
#options.zabbixUser = "Admin"
#options.zabbixPassword = "zabbix"
#options.zabbixHost = "localhost"
#options.zabbixHostTimeout = 10
#options.pollingWindow = 300 # 5 minutes
#options.loggingLevel = logginglevel=Logger::INFO        


class Options

    
  def initialize(program_name)
    @program_name = program_name
  end

  #
  # Return a structure describing the options.
  #
  def parse(args)
    options = {}

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{@program_name} [options]"

      opts.separator ""
      opts.separator "Specific options:"
      opts.on("-l","--logging-level LEVEL", [:DEBUG,:INFO,:WARN,:ERROR,:FATAL], "Logging level DEBUG,INFO,WARN,ERROR,FATAL (default: INFO)") do |l|
        options[:logging_level] = l
      end

      opts.separator ""
      opts.on("-o","--org-id ORG_ID", "Boundary Organization ID") do |o|
        options[:org_id] = o
      end
      opts.on("-k","--api-key APIKEY", "Boundary API key") do |k|
        options[:api_key] = k
      end
      opts.on("-H","--boundary-api-host API_HOST", "Boundary API Host (default: api.boundary.com)") do |h|
        options[:api_host] = h
      end
        
      opts.separator ""
      opts.on("--zabbix-user USER","Zabbix user name (default: Admin)") do |u|
        options[:zabbix_user] = u
      end
      opts.on("--zabbix-password PASSWORD", "Zabbix user password (default: zabbix)") do |p|
        options[zabbix_password] = p
      end
      opts.on("--zabbix-api-host HOST","Zabbix API host (default: localhost)") do |z|
        options[:zabbix_api_host] = z
      end
      opts.separator ""
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      # Another typical switch to print the version.
      opts.on_tail("-v","--version", "Show version") do
        boundary_version="1.00.03"
        zabbix_version="0.01.00"
        
        puts "Boundary API Version: #{boundary_version}"
        puts "Zabbix Integration Version: #{zabbix_version}"
        exit
      end
    end
    
    begin
      opt_parser.parse!(args)
      options

      mandatory = [:org_id, :api_key]                                         # Enforce the presence of
      missing = mandatory.select{ |param| options[param].nil? }        # the -t and -f switches
      if not missing.empty?                                            #
        puts "Missing options: #{missing.join(', ')}"                  #
        puts opt_parser                                                #
        exit
      end
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument      #
      puts $!.to_s                                                           # Friendly output when parsing fails
      puts opt_parser                                                          #
      exit                                                                   #
    end
    options
  end  # parse()
end  # class OptionsParser


