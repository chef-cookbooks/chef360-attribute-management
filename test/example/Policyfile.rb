# Policyfile.rb - Describe how you want Chef Infra Client to build your system.
#
# For more information on the Policyfile feature, visit
# https://docs.chef.io/policyfile/

# A name that describes what the system you're building with Chef does.
name 'your_wrapper_cookbook'

# Where to find external cookbooks:
default_source :supermarket
default_source :chef_server, < Your chef server URL , if your cookbook is placed in chef server >


# run_list: chef-client will run these recipes in the order specified.
run_list 'your_wrapper_cookboo::default'

# Specify a custom source for a single cookbook:
cookbook 'your_wrapper_cookboo', path: '.'
