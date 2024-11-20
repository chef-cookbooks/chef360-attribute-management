#
# Chef Infra Documentation
# https://docs.chef.io/libraries/
#
#
module Ohaiserver
  module ApiTokenHelperHelpers
    def get_new_access_token(api_url, access_key, secret_key)
      url = "#{api_url}/platform/user-accounts/v1/user/api-token/login"
      payload = { 'accessKey' => access_key, 'secretKey' => secret_key, 'state' => 'random-string' }
      uri = URI.parse(url)
      header = { 'Content-Type' => 'application/json' }
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = payload.to_json
      response = http.request(request)
      response = handle_response(response)
      data = JSON.parse(response.body)
      oauth_code = data['item']['oauthCode']

      url = "#{api_url}/platform/user-accounts/v1/user/api-token/jwt"
      payload = { 'oauthCode' => oauth_code, 'state' => 'random-string' }
      uri = URI.parse(url)
      header = { 'Content-Type': 'application/json' }
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = payload.to_json
      response = http.request(request)
      response = handle_response(response)
      data = JSON.parse(response.body)
      access_token = data['item']['accessToken']
      refresh_token = data['item']['refreshToken']
      [access_token, refresh_token]
    end

    def http_request(url, payload, access_token = nil)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = if http_method == 'put'
                  Net::HTTP::Put.new(uri.request_uri)
                else
                  Net::HTTP::Post.new(uri.request_uri)
                end
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{access_token}" if access_token
      request.body = payload.to_json
      response = http.request(request)
      response = handle_response(response)

      JSON.parse(response.body)
    end

    def handle_response(response)
      max_retries = 3
      attempts = 0

      begin
        case response
        when Net::HTTPSuccess
          Chef::Log.info("Success: #{response.body}")
        else
          Chef::Log.error("HTTP Error: #{response.code} #{response.message}")
          raise SocketError
        end
        response
      rescue SocketError, Timeout::Error => e
        attempts += 1
        if attempts < max_retries
          Chef::Log.warn("#{url} failed. Retrying...(attempt #{attempts})")
          retry
        else
          Chef::Log.fatal("#{url} failed. Stopping Chef client")
          raise "Failed after #{max_retries} attempts: #{e.message} for API: #{url}"
        end
      rescue StandardError => e
        Chef::Log.fatal("An error occurred for API #{url}: #{e.message}")
        raise "An error occurred for API #{url}: #{e.message}"
      end
    end
  end
end
