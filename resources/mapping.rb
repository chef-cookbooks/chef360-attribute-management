require 'yaml'
require 'net/http'
require 'json'
require 'uri'
require 'openssl'

provides :mapping
unified_mode true

property :nm_namespace, String, name_property: true
property :chef_attrs, Array, default: []
property :api_url, String, default: lazy { node['api_url'] }
property :access_key, String, default: lazy { node['access_key'] }, sensitive: true
property :secret_key, String, default: lazy { node['secret_key'] }, sensitive: true
property :http_method, Symbol, default: :patch, equal_to: [:patch, :put]
# property :cli_command, String, required: true

action_class do
  include Ohaiserver::ApiTokenHelperHelpers
end

action :map do
  protected_namespaces = %w(agent aws enroll gohai azure)

  # Check if the provided namespace is in the list of protected namespaces
  if protected_namespaces.include?(new_resource.nm_namespace)
    raise "The namespace '#{new_resource.nm_namespace}' is protected and cannot be used."
  end
  # Initialize an Ohai system object to collect data
  ohai = ::Ohai::System.new
  ohai.all_plugins
  ohai_output = ohai.data

  # initialises an empty hash set
  # if new_resource.http_method == :PUT  &&
  captured_attrs = {}
  
  # Define the path to the NODE GUID file to extract NODE ID

  node_guid_path = if platform_family?('windows')
                     'C:/hab/svc/node-management-agent/data/node_guid'
                   else
                     '/hab/svc/node-management-agent/data/node_guid'
                   end

  # Check if the file exists
  if ::File.exist?(node_guid_path)
    node_id = ::File.read(node_guid_path).strip
    if node_id.empty?
      raise "Node ID is empty in the file at #{node_guid_path}"
    end
    
    # Validate UUID format (basic validation)
    unless node_id.match?(/\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/)
      raise "Invalid Node ID format in #{node_guid_path}. Expected UUID format, got: #{node_id}"
    end
  else
    raise "Node GUID file not found at #{node_guid_path}"
  end

  # Log the extracted node_id to Chef logs
  log "Extracted node_id: #{node_id}" do
    level :info
  end

  # Use the node_id as needed in your Chef custom resource

  node.default['courier']['node_id'] = node_id
  access_token, = get_new_access_token(new_resource.api_url, new_resource.access_key, new_resource.secret_key)

  new_resource.chef_attrs.each do |attr|
    attr[:nm_attr_name] = attr[:nm_attr_name].downcase if attr[:nm_attr_name]
  end
  # Iterate through each attribute mapping specified in the chef_attrs property
  new_resource.chef_attrs.each do |attr|
    if attr[:chef_attr_name].start_with?("node['")
      # Safely extract attribute path from node['...'] format
      attr_path = attr[:chef_attr_name].match(/node\['([^']+)'\]/)[1]
      if attr_path.nil?
        raise "Invalid chef_attr_name format: #{attr[:chef_attr_name]}. Expected format: node['attribute_name']"
      end
      
      # Fetch the attribute value from node attributes safely
      value = node[attr_path]
      # Check if the attribute value is nil
      if value.nil?
        raise "Invalid attribute value for chef_attr_name '#{attr[:chef_attr_name]}'. Value is nil."
      end
    else
      # Fetch the attribute value from Ohai output
      value = ohai_output.dig(*attr[:chef_attr_name].split('/'))
      
      # Check if the Ohai attribute value is nil
      if value.nil?
        raise "Ohai attribute '#{attr[:chef_attr_name]}' not found or is nil. Available Ohai attributes: #{ohai_output.keys.join(', ')}"
      end
    end
    # Use the custom name (if provided) or the last part of the chef_attr_name as the key
    key = attr[:nm_attr_name] || attr[:chef_attr_name].split('/').last

    # Store the captured attribute in the captured_attrs hash
    captured_attrs[attr[:chef_attr_name]] = { key => value }
  end

  # Create an array to store the JSON formatted output
  json_output = new_resource.chef_attrs.map do |attr|
    key = attr[:nm_attr_name] || attr[:chef_attr_name].split('/').last
    value = captured_attrs[attr[:chef_attr_name]][key]

    # Check if the value is nil and raise an error
    if value.nil?
      raise "Invalid attribute value for chef_attr_name '#{attr[:chef_attr_name]}'. Value is nil."
    end

    {
      'name' => key,
      'value' => value,
    }
  end

  # Store the formatted JSON output in node.run_state for later use
  node.run_state['mapping_json'] ||= {}
  node.run_state['mapping_json'][new_resource.nm_namespace] = json_output

  # Log the captured attributes to verify the output
  log 'print_ohai_attrs' do
    message JSON.pretty_generate(json_output)
    level :info
  end

  api_endpoint = "#{new_resource.api_url}/node/management/v1/nodes/#{node_id}/attributes/#{new_resource.nm_namespace}"

  # Make the PATCH request to the API endpoint with the JSON data
  ruby_block 'push_json_to_server' do
    block do
      uri = URI(api_endpoint)
      http = Net::HTTP.new(uri.hostname, uri.port)
      
      # Configure SSL for HTTPS requests - default to VERIFY_NONE for enterprise environments
      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      
      request_class = Net::HTTP.const_get(new_resource.http_method.capitalize)
      request = request_class.new(uri, 'Content-Type' => 'application/json')
      request['Authorization'] = "Bearer #{access_token}"
      request.body = json_output.to_json
      
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise "Failed to push JSON to server: #{response.code} #{response.message} - #{response.body}"
      end
    end
    action :run
  end
end
