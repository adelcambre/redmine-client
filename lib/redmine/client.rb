require 'faraday'
require 'faraday_middleware'
require 'redmine/client/version'
require 'redmine/client/authorization_token'

module Redmine
  class Client
    class ResponseError < StandardError
      attr_reader :response
      def initialize(response)
        @response = response
      end

      def body
        response.body
      end

      def message
        "Error #{response.status}: #{response.body}"
      end
    end

    class << self
      attr_accessor :base_url
      attr_writer :raise_on_error
      def raise_on_error?
        return @raise_on_error if defined?(@raise_on_error)

        @raise_on_error = true
      end
    end

    attr_reader :base_url, :access_key

    def initialize(access_key, base_url=nil)
      @access_key = access_key
      @base_url = base_url || self.class.base_url

      unless @base_url
        raise ArgumentError, "You must provide an api base url, either Redmine::Client.new(token, base_url) or Redmine::Client.base_url = base_url"
      end
    end

    def faraday
      @faraday ||= Faraday.new(:url => base_url) do |f|
        f.request :json
        f.request :authorization_token, access_key
        f.adapter Faraday::default_adapter
        f.response :json, :content_type => /\bjson$/
      end
    end

    def self.crud(plural, singular)
      class_eval <<-EOF, __FILE__, __LINE__
        def create_#{singular}(params, full_response=false)
          resp = faraday.post("/#{plural}.json", {"#{singular}" => params})
          check_errors(resp)
          full_response ? resp : resp.body
        end

        def find_#{singular}(id, full_response=false)
          resp = faraday.get("/#{plural}/\#{id}.json")
          check_errors(resp)
          full_response ? resp : resp.body
        end

        def update_#{singular}(id, params, full_response=false)
          resp = faraday.put("/#{plural}/\#{id}.json", {"#{singular}" => params})
          check_errors(resp)
          full_response ? resp : resp.body
        end

        def delete_#{singular}(id, full_response=false, raise_on_error=true)
          resp = faraday.delete("/#{plural}/\#{id}.json")
          check_errors(resp)
          full_response ? resp : resp.body
        end
      EOF

    end

    crud :users, :user
    crud :projects, :project
    crud :issues, :issue

    def add_member_to_project(user_id, project_id, role_ids=[3])
      faraday.post("/projects/#{project_id}/memberships.json", {
        "membership" => {
          "user_id"  => user_id,
          "role_ids" => Array(role_ids),
        }})
    end

    def check_errors(response)
      return if response.success?
      $stderr.puts "REDMINE ERROR (#{response.status}): #{response.body}"

      if self.class.raise_on_error?
        raise ResponseError.new(response)
      end
    end
  end
end
