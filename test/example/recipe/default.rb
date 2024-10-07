# below is the example usage of the recipe file in cookbook and the below is refernce example

chef_attrs = [
    { chef_attr_name: 'platform', nm_attr_name: 'platform_name' },
    { chef_attr_name: 'hostname', nm_attr_name: 'host_name' },
    { chef_attr_name: "node['policy_name']", nm_attr_name: 'policy_name' },
    { chef_attr_name: "node['policy_group']", nm_attr_name: 'policy_group' },
    { chef_attr_name: 'memory/swap/total', nm_attr_name: 'memoryfree' },
  ]

mapping 'progress' do
  nm_namespace 'Progress_chef'
  chef_attrs chef_attrs
  api_url node['api_url']
  access_key node['access_key']
  secret_key node['secret_key']
  http_method :put # or :put, depending on your requirement. Please make sure of what you want to use in your case PATCH or PUT
  action :map
end
