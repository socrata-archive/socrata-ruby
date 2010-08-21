#!/usr/bin/env ruby

# Copyright (c) 2010 Socrata.
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

require 'logger'
require 'rubygems'
require 'httparty'
require 'curb'
require 'json'
require 'date'
require 'pp'

# Dynamically load dependencies
dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'socrata/data')

class Socrata
  include HTTParty

  attr_reader :error, :config, :batching

  default_options[:headers] = {'Content-type' => 'application/json'}
  format :json

  DEFAULT_CONFIG = {
    :base_uri => "http://www.socrata.com/api"
  }

  def initialize(params = {})
    @config = DEFAULT_CONFIG.merge(symbolize_keys(params))
    @logger = @config[:logger] || Logger.new(STDOUT)
    @batching = false
    @batch_queue = []

    if @config[:username]
      self.class.basic_auth(@config[:username],
                            @config[:password])
    else
      self.class.default_options[:basic_auth] = nil
    end

    self.class.base_uri @config[:base_uri]

    # Keep around a self reference because we need it
    @party = self.class
  end

  def user(uid_or_login)
    return User.new(get_request("/users/#{uid_or_login}.json"), @party)
  end

  def view(uid)
    return View.new(get_request("/views/#{uid}.json"), @party)
  end

  def create(name, description = "", tags = [], public = true)
    data_hash = { 'name' => name, 'description' => description }
    data_hash[:tags] = tags unless tags.empty?

    # Set public flag if public, defaults to private with no flags
    data_hash[:flags] = ['dataPublic'] if public

    # Post to views service, creating a new dataset
    return View.new(post_request('/views.json', :body => data_hash.to_json), @party)
  end

  # Create a new dataset by importing (uploading) a file
  def import(filename)
    if @batching
      raise "Error: Cannot do imports as part of a batch"
    end

    response = multipart_post_file("/imports", filename)
    check_error!(response)
    return View.new(response, @party)
  end

  # Wrap a proc for a batch request
  def batch_request()
    @batching = true
    @batch_queue = []
    yield
    @batching = false
    flush_batch_queue();
  end

  protected
    def get_request(path, options = {})
      if @batching
        # Batch up the request
        @batch_queue << {:url => path, :requestType => "GET"}
      else
        # Actually execute the request
        response = @party.get(path, options);
        check_error! response
        return response
      end
    end

    def post_request(path, options = {})
      if @batching
        # Batch up the request
        @batch_queue << {:url => path, :body => options[:body], :requestType => "POST"}
      else
        # Actually execute the request
        response = @party.post(path, options)
        check_error! response
        return response
      end
    end

    def put_request(path, options = {})
      if @batching
        # Batch up the request
        @batch_queue << {:url => path, :body => options[:body], :requestType => "PUT"}
      else
        # Actually execute the request
        response = @party.put(path, options)
        check_error! response
        return response
      end
    end

    def delete_request(path, options = {})
      if @batching
        # Batch up the request
        @batch_queue << {:url => path, :body => options[:body], :requestType => "DELETE"}
      else
        # Actually execute the request
        response = @party.delete(path, options)
        check_error! response
        return response
      end
    end

    # Flush a queued batch of requests
    def flush_batch_queue
      if !@batch_queue.empty?
        result = @party.post('/batches', :body => {:requests => @batch_queue}.to_json)
        results_parsed = JSON.parse(result.body)
        if results_parsed.is_a? Array
          results_parsed.each_with_index do |result, i|
            if result['error']
              raise "Received error in batch response for operation " +
                @batch_queue[i][:requestType] + " " + @batch_queue[i][:url] + ". Error: " +
                result['errorCode'] + " - " + result['errorMessage']
            end
          end
        else
          raise "Expected array response from a /batches request, and didn't get one."
        end
        @batch_queue.clear
      end
      return results_parsed
    end

    # Reads response and checks for error code
    def check_error!(response)
      if !response.nil? && response['error']
        raise "Got error from server: Code: #{response['code']}, Message: #{response['message']}"
      end
    end

    # Sends a multipart-formdata encoded POST request
    def multipart_post(url, contents, field = 'file', mimetype = "application/json")
      c = Curl::Easy.new(@party.default_options[:base_uri] + url.to_s)
      c.multipart_form_post = true

      c.userpwd = @party.default_options[:basic_auth][:username] +
        ":" + @party.default_options[:basic_auth][:password]
      c.http_post(Curl::PostField.content(field, contents, mimetype))

      return JSON.parse(c.body_str)
    end

    def multipart_post_file(url, filename, field = 'file', remote_filename = filename)
      c = Curl::Easy.new(@party.default_options[:base_uri] + url.to_s)
      c.multipart_form_post = true

      c.userpwd = @party.default_options[:basic_auth][:username] +
        ":" + @party.default_options[:basic_auth][:password]
      c.http_post(Curl::PostField.file(field, filename, remote_filename))

      return JSON.parse(c.body_str)
    end

    def symbolize_keys(obj)
      case obj
      when Array
        obj.inject([]){|res, val|
          res << case val
          when Hash, Array
            symbolize_keys(val)
          else
            val
          end
          res
        }
      when Hash
        obj.inject({}){|res, (key, val)|
          nkey = case key
          when String
            key.to_sym
          else
            key
          end
          nval = case val
          when Hash, Array
            symbolize_keys(val)
          else
            val
          end
          res[nkey] = nval
          res
        }
      else
        obj
      end
    end
end
