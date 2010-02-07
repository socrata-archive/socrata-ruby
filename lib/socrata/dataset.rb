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

module Socrata
  class Dataset < SocrataAPI

    # Create a new dataset, returns and stores the resultant four-four ID
    def create(title='Socrata API Upload', description='', tags = [], public = true)
      data_hash = { 'name' => title, 'description' => description }

      # Set public flag if public, defaults to private with no flags
      data_hash[:flags] = ['dataPublic'] if public

      data_hash[:tags] = tags unless tags.empty?

      # Post to views service, creating a new dataset
      response = self.class.post('/views.json', :body => data_hash.to_json)
      # Save and return the four-four
      if response['id'].nil?
        @logger.error("Error creating dataset: #{response.message}")
        @error = response['code']
        return false
      end
      @data = response
      @id = response['id']
    end
    
    # Create a new dataset by importing (uploading) a file
    def import(filename)
      multipart_upload("/imports", filename)
      check_error
      if !@response['id'].nil? && is_id(@response['id'])
        @id = @response['id']
        @logger.info("Imported dataset: '#{@response['name']}' (#{@id})")
      else
        @logger.error("Did not recieve a valid UID in response from ImportsService")
      end
    end
    
    # Delete's the current dataset
    def delete
      response = self.class.delete("/views.json?id=#{@id}&method=delete")
    end

    # Turns a Ruby date object into a string that the API will recognize
    def parse_date(date)
      d = DateTime.strptime(date, @config['date']['format'])
      return d.strftime(@config['date']['output']) + " GMT"
    end

    # Adds a row, immediately posting result to the API server.
    # If you will be adding multiple rows, consider batching the requests via add_row_delayed,
    # Then passing those results as an array to batch_request
    def add_row(data)
      if not self.attached?
        @logger.error("No ID is associated, cannot add row")
        return false
      end

      @response = self.class.post("/views/#{@id}/rows.json",
        :body => data.to_json)
      check_error
    end
  
    # For batch upload, saves a request to post later
    def add_row_delayed(data)
      return unless self.attached?
      @batch_requests = Array.new if @batch_requests.nil?
      @batch_requests << {:url => "/views/#{@id}/rows.json", :requestType => "POST", :body => data.to_json}
    end
  
    # Creates a new column in the dataset
    def add_column(name, description = nil,  type='text', hidden=false, rich=false, width = 100)
      if not self.attached?
        @logger.error("No ID is associated, cannot add column")
        return false
      end
      @logger.info("Creating column '#{name}' of type '#{type}'")
      data = 
      { :name => name,
        :dataTypeName => type,
        :description => description,
        :hidden => hidden,
        :width => width }
      data[:format] = {:formatting_option => 'Rich'} if rich

      @response = self.class.post("/views/#{@id}/columns.json",
        :body => data.to_json)
      check_error
    end
    
    # Uploads an image for use in the dataset, returning the ID string to use in rows
    def upload_image(filename)
      multipart_upload("/views/#{@id}/files.txt", filename)
      @response['file']
    end

    # Sends a multipart-formdata encoded POST request
    def multipart_upload(url, file, field = 'file')
      c = Curl::Easy.new(@config['server']['host'] + url.to_s)
      c.multipart_form_post = true

      c.userpwd = @config['credentials']['user'] + ":" + @config['credentials']['password']
      c.http_post(Curl::PostField.file(field, file))
      
      @response = JSON.parse(c.body_str) unless c.body_str.nil?
    end
  
    # Use an existing dataset by specifying its four-four ID.
    def attach(id)
      if self.is_id(id)
        @id = id
        @logger.info("Working on existing dataset: id #{@id}")
      else
        @logger.error("Invalid ID specified in attach(): '#{id}'. Ignoring")
      end
    end
  
    def is_id(id)
      id =~ /[0-9a-z]{4}-[0-9a-z]{4}/
    end
  
    def attached?
      self.is_id(@id)
    end
  
    # Returns an array of columns for the dataset
    def get_columns
      if not self.attached?
        @logger.error("Can't get columns: not attached to a view")
        return
      end
    
      @response = self.class.get("/views/#{@id}/columns.json")
      check_error
    end
  
    # Returns an array of rows for the dataset
    def get_rows
      return unless self.attached?
      @response = self.class.get("/views/#{@id}/rows.json")
      check_error
    end
  
    # Returns true if there are columns in the datasets
    def has_columns?
      # There will always be an invisible 'tags' column
      self.get_columns.length > 1
    end
  
    # Find sets from the API server
    def find_sets(options = {})
      username = options[:username] || @config['credentials']['user']

      results = self.class.get("/users/#{username}/views")
      
      if options[:tags]
        results = results.select { |v| v['tags'] && v['tags'].include?(options[:tags]) }
      end
    
      if options[:ignore]
        results.delete_if {|v| v['tags'] && v['tags'].include?(options[:ignore])}
      end
      
      results
    end
  
    # Mark a dataset as public or private
    def set_public(public = true)
      return unless self.attached?
      param = public ? 'public' : 'private'
      @response = self.class.get("/views/#{@id}?method=setPermission&value=#{param}")
      check_error
    end
  
    # Abstract put request, used below
    def put(body)
      return unless self.attached?
      @response = self.class.put("/views/#{@id}", :body => body.to_json)
      @logger.info("Put request finished with #{body.inspect}")
    end
  
    def set_attribution(attribution, link)
      self.put(:attributionLink => link, :attribution => attribution)
    end
  
    def set_description(description)
      self.put(:description => description.to_s)
    end
  
    def set_tags(tags)
      self.put(:tags => tags)
    end
  
    # Returns an href to the dataset
    def link_url(options = {})
      category = options[:category] || @config['dataset']['category']
      name = options[:name] || 'Socrata-Dataset'
      # TODO: Generalize
      "#{@config['server']['public_host']}/#{category}/#{name}/#{@id}"
    end
  
    # Returns a shortened href to the dataset
    def short_url
      "#{@config['server']['public_host']}/d/#{@id}"
    end
  
    # Returns HTML code to embed a widget of the dataset
    def embed_code(width=500, height=425)
      "<iframe width=\"#{width}px\" height=\"#{height}px\" src=\"#{@config['server']['public_host']}/widgets/#{@id}\" " +
        "frameborder=\"0\" scrolling=\"no\"></iframe>"
    end
  end
end