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

include_recipe "chef_handler"

boundary_account = data_bag_item("boundary", "account")

cookbook_file "#{Chef::Config[:file_cache_path]}/chef-boundary-events-handler.rb" do
  source "chef-boundary-events-handler.rb"
  mode "0600"
end

cookbook_file "#{Chef::Config[:file_cache_path]}/boundary-cacert.pem" do
  source 'cacert.pem'
  owner 'root'
  group 'root'
  mode '0600'
end

chef_handler "BoundaryEvents" do
  source "#{Chef::Config[:file_cache_path]}/chef-boundary-events-handler.rb"
  arguments [
             :orgid => boundary_account["orgid"],
             :apikey => boundary_account["apikey"]
  ]
  action :enable
end
