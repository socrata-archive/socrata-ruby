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

class Socrata
  class Data < Socrata
    attr_reader :data

    def initialize(data, party)
      @data = data
      @party = party
    end

    def method_missing(method)
      key = @data[method.to_s]
    end

    def id
      @data["id"]
    end

    #def inspect
      #data = @data.inject([]) { |collection, key| collection << "#{key[0]}: #{key[1]['data']}"; collection }.join("\n    ")
      #"#<#{self.class}:0x#{object_id}\n    #{data}>"
    #end
  end

  class User < Data; end

  class View < Data
    # Get the rows for this View as a raw array of arrays
    def raw_rows(params = {})
      return get_request("/views/#{self.id}/rows.json", :query => params)
    end

    # Get the rows as an array of hashes by their column ID or something
    # overriden with the second param
    def rows(params = {}, by = "name")
      # TODO: I really hate this method, I'd like to redo it.

      # Get the raw rows
      response = get_request("/views/#{self.id}/rows.json", :query => params)

      # Create a mapping from array index to ID
      columns = response["meta"]["view"]["columns"]
      mapping = Hash.new
      columns.each_index do |idx|
        mapping[idx] = columns[idx][by]
      end

      # Loop over the rows, replacing each with a proper hash
      rows = response["data"]
      new_rows = Array.new
      rows.each do |row_arr|
        row_hash = Hash.new

        # Loop over the row, building our hash
        row_arr.each_index do |idx|
          row_hash[mapping[idx]] = row_arr[idx]
        end

        # Add a few meta columns
        row_hash["_id"] = row_arr[0]

        new_rows.push row_hash
      end

      return new_rows
    end

    def push_row(row_hash)
      return post_request("/views/#{self.id}/rows.json", :body=> row_hash.to_json)
    end

    def get_row(row_id)
      return get_request("/views/#{self.id}/rows/#{row_id}.json")
    end

    def update_row(row_id, row_hash)
      return put_request("/views/#{self.id}/rows/#{row_id}.json", :body=> row_hash.to_json)
    end

    # Bulk append rows to an existing dataset
    def append(filename, skip_headers = false)
      if @batching
        raise "Error: Cannot perform an append as part of a batch"
      end

      response = multipart_post_file("/views/#{self.id}/rows?method=append&skip_headers=#{skip_headers}", filename)
      check_error!(response)
      return response
    end

    # Bulk replace rows in an existing dataset
    def replace(filename, skip_headers = false)
      if @batching
        raise "Error: Cannot perform a replace as part of a batch"
      end

      response = multipart_post_file("/views/#{self.id}/rows?method=replace&skip_headers=#{skip_headers}", filename)
      check_error!(response)
      return response
    end

    # Destructively truncate all the rows
    def truncate!
      if @batching
        raise "Error: Cannot truncate as part of a batch"
      end

      # Do a replace with an empty file and a fake filename. /dev/null is
      # conveniently empty. :)
      response = multipart_post_file("/views/#{self.id}/rows?method=replace", "/dev/null", "file", "empty_file.csv")
      check_error!(response)
      return response
    end

    # Destructively deletes the current dataset
    def delete!
      return delete_request("/views/#{self.id}")
    end
  end
end

__END__
  class Dataset < SocrataAPI
    ##########################
    # Consumer-facing Features
    ##########################

    # Returns an array of columns for the dataset
    def columns
      if not self.attached?
        @logger.error("Can't get columns: not attached to a view")
        return
      end

      @response = self.class.get("/views/#{@id}/columns.json")
      check_error
    end

    ##########################
    # Publisher-only features
    ##########################

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
      param = public ? 'public.read' : 'private'
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

    # Turns a Ruby date object into a string that the API will recognize
    def parse_date(date)
      d = DateTime.strptime(date, @config['date']['format'])
      return d.strftime(@config['date']['output']) + " GMT"
    end

  end
