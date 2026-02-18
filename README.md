# chef360-attribute-management

TODO: Enter the cookbook description here.

# chef360-attribute-management

# Chef Cookbook: Mapping Custom Resource
`Overview`

This Chef cookbook provides a custom resource named mapping that facilitates the mapping of Chef attributes to a specified namespace and sends these attributes to a designated server endpoint using either the PATCH or PUT HTTP methods. The resource can be configured to push data based on user requirements.

# Features

•	`Attribute Mapping`: Map specified Chef attributes to custom names and namespaces.

•	`HTTP Method Flexibility`: Choose between PATCH and PUT methods for sending data to the server.

•	`Namespace Protection`: Prevent the use of protected namespaces to avoid conflicts.

•	`Dynamic Configuration`: Fetch and parse configuration details from a YAML file.

•	`Token Management`: Obtain and manage access tokens for secure API communication.

•	`Logging`: Log important information and errors for troubleshooting and audit purposes.

# Configuration and Usage
`Step 1: Define Attributes`
Define the Chef attributes to be mapped and their corresponding custom names. This is done in the chef_attrs property of the mapping resource.

`Step 2: Specify Namespace`
Provide the namespace where the attributes will be stored. Ensure that the namespace is not protected to avoid conflicts. The namespace is input from user with any user defined name. Here you can define name under nm_namespace.

`Step 3: Set API Details`
Set the API URL, access key, and secret key for authentication. These values can be defined in the attribute file (attributes/default.rb) .

`Step 4: Choose HTTP Method`
Specify whether to use PATCH or PUT for sending data.

``Patch`` : Use this operation to modify a node's namespaced attributes. This operation replaces the existing attribute value with the new one and adds any missing attributes.

``Put:`` Use this operation to update a node's namespaced attributes. If any attributes exist for the given namespace, this operation completely replaces the old attributes with the new ones.

# Example Configuration
In your recipe (e.g., recipes/default.rb), configure the mapping resource as follows:
```
chef_attrs = [

    { chef_attr_name: 'platform', nm_attr_name: 'platform_name' },
    { chef_attr_name: 'hostname', nm_attr_name: 'host_name' },
    { chef_attr_name: "node['policy_name']", nm_attr_name: 'policy_name' },
    { chef_attr_name: "node['policy_group']", nm_attr_name: 'policy_group' },
    { chef_attr_name: 'memory/swap/total', nm_attr_name: 'memoryfree' },
]
```
```
mapping 'progress' do

  nm_namespace 'Progress_chef'

  chef_attrs chef_attrs

  api_url node['api_url']

  access_key node['access_key']

  secret_key node['secret_key']

  http_method :put # or :patch, depending on your requirement

  action :map

end
```

# Details of Custom Resource Properties
•  `nm_namespace`: (String) The namespace to which the Chef attributes will be mapped.   This is a required property and also serves as the name property of the resource. The user can define this as per their requirements.

•  `chef_attrs`: (Array) An array of attribute mappings, each specifying a Chef attribute and its corresponding custom name. Each chef_attr_name should exactly match the Ohai attribute path. Default is an empty array.

•	`chef_attr_name`: This should be the exact value of an Ohai attribute, for example, platform, hostname, or more complex paths like memory/swap/total.

•	`nm_attr_name`: This is a user-defined name and can be any name given by the user. The attribute value will be stored under this name in the node management system.

•  `api_url`: (String) The URL of the API endpoint to which data will be sent. Defaults to the value in node['api_url'].

•  `access_key`: (String) The access key used for authentication. Defaults to the value in node['access_key'].

•  `secret_key`: (String) The secret key used for authentication. Defaults to the value in node['secret_key'].

•  `http_method`: (Symbol) The HTTP method to use for the request (:patch or :put). Default is :patch.

# Example Attribute File Configuration
Define the default values for the access key, secret key, and API URL in the attribute file (attributes/default.rb):
```
default['access_key'] = '<Insert_your_access_key_>'
default['secret_key'] = '<Insert your secret key from your 360 server>'
default['api_url'] = '<add your 360 server api with your port.'
```


# Expected Output
Upon successful execution, the custom resource will:
1.	Fetch and map the specified Chef attributes to custom names.
2.	Log the mapped attributes.
3.	Send the mapped attributes as JSON to the specified API endpoint using the chosen HTTP method (PATCH or PUT).
4.	Log the response from the server and raise an error if the request fails.

# When to Use PUT and When to Use PATCH
•	`PUT`: Use the PUT method when you want to completely replace the existing resource on the server with the new data. PUT should be used when you have a complete representation of the resource.

•	`PATCH`: Use the PATCH method for partial updates to the resource. PATCH is suitable when you only want to modify specific fields of the resource without affecting the entire resource.

# Error Handling

•	The resource will raise an error if the specified namespace is protected.

•	It will also raise an error if any attribute value is nil during the fetching process.


# Reference Files
For your convenience, sample files have been provided to help you get started quickly. You can refer to the following sample files under the path:

```
chef360-attribute-management/test/example
```
These files include:

`recipe/default.rb`: Example recipe using the custom resource.

`Policyfile`: A sample policy file to guide you in setting up your policy-based workflow.

`metadata.rb`: Example metadata file showing how to declare dependencies.

`Attributes` file: A sample attributes file demonstrating attribute setup.

These samples are intended to serve as a reference, allowing you to adapt and customize them according to your specific requirements.

# Key Points to Remember:
`Custom Namespace`s: Users can define their own `nm_namespace` in the `mapping` block.

`Chef Attribute Names`: The `chef_attr_name` values should exactly match the Ohai attributes you wish to map. For example, if you're using `platform`, ensure that Ohai returns a value for `platform`.

`NM Attribute Names`: The `nm_attr_name` is user-defined and can be any name of your choosing. The corresponding value will be stored under this name in your node management attributes.

`PUT vs PATCH`: Use `PUT` when you want to completely overwrite the existing data at the endpoint. Use `PATCH` when you want to update only specific fields without affecting the others.

# Copyright

See [COPYRIGHT.md](./COPYRIGHT.md).