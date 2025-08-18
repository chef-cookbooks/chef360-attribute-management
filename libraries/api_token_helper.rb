#
# Chef Infra Documentation
# https://docs.chef.io/libraries/
#
require 'net/http'
require 'json'
require 'uri'
require 'openssl'

module Ohaiserver
  module ApiTokenHelperHelpers
    def get_new_access_token(api_url, access_key, secret_key, ssl_mode = 'verify_none')
      # Validate inputs
      raise "API URL cannot be nil or empty" if api_url.nil? || api_url.strip.empty?
      raise "Access key cannot be nil or empty" if access_key.nil? || access_key.strip.empty?
      raise "Secret key cannot be nil or empty" if secret_key.nil? || secret_key.strip.empty?
      
      url = "#{api_url}/platform/user-accounts/v1/user/api-token/login"
      payload = { 'accessKey' => access_key, 'secretKey' => secret_key, 'state' => 'random-string' }
      response = make_http_request(url, payload, nil, 'post', ssl_mode)
      data = JSON.parse(response.body)
      oauth_code = data['item']['oauthCode']

      url = "#{api_url}/platform/user-accounts/v1/user/api-token/jwt"
      payload = { 'oauthCode' => oauth_code, 'state' => 'random-string' }
      response = make_http_request(url, payload, nil, 'post', ssl_mode)
      data = JSON.parse(response.body)
      access_token = data['item']['accessToken']
      refresh_token = data['item']['refreshToken']
      [access_token, refresh_token]
    end

    def http_request(url, payload, access_token = nil, method = 'post', ssl_mode = 'verify_none')
      response = make_http_request(url, payload, access_token, method, ssl_mode)
      JSON.parse(response.body)
    end

    private

    def make_http_request(url, payload, access_token = nil, method = 'post', ssl_mode = 'verify_none')
      max_retries = 3
      attempts = 0
      
      begin
        attempts += 1
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          if ssl_mode == 'verify_peer'
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end
        end
        
        request = case method.downcase
                  when 'put'
                    Net::HTTP::Put.new(uri.request_uri)
                  else
                    Net::HTTP::Post.new(uri.request_uri)
                  end
        
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{access_token}" if access_token
        request.body = payload.to_json
        
        response = http.request(request)
        
        # Handle redirects manually
        response = follow_redirects(response, payload, access_token, method, ssl_mode) if response.is_a?(Net::HTTPRedirection)
        
        unless response.is_a?(Net::HTTPSuccess)
          Chef::Log.error("HTTP Error: #{response.code} #{response.message}")
          raise "HTTP Error: #{response.code} #{response.message}"
        end
        
        Chef::Log.info("Success: #{response.code} #{response.message}")
        response
        
      rescue StandardError => e
        if attempts < max_retries
          Chef::Log.warn("#{url} failed. Retrying...(attempt #{attempts})")
          sleep(2 ** attempts) # Exponential backoff
          retry
        else
          Chef::Log.fatal("#{url} failed. Stopping Chef client")
          raise "Failed after #{max_retries} attempts: #{e.message} for API: #{url}"
        end
      end
    end

    def follow_redirects(response, payload, access_token, method, ssl_mode, max_redirects = 5)
      redirects = 0
      
      while response.is_a?(Net::HTTPRedirection) && redirects < max_redirects
        redirects += 1
        location = response['location']
        
        if location.nil? || location.empty?
          raise "Redirect response missing location header"
        end
        
        Chef::Log.info("Following redirect to: #{location}")
        
        uri = URI.parse(location)
        http = Net::HTTP.new(uri.host, uri.port)
        
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          if ssl_mode == 'verify_peer'
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end
        end
        
        request = case method.downcase
                  when 'put'
                    Net::HTTP::Put.new(uri.request_uri)
                  else
                    Net::HTTP::Post.new(uri.request_uri)
                  end
        
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{access_token}" if access_token
        request.body = payload.to_json
        
        response = http.request(request)
      end
      
      if redirects >= max_redirects && response.is_a?(Net::HTTPRedirection)
        raise "Too many redirects (#{redirects}) when accessing API"
      end
      
      response
    end
  end
end
