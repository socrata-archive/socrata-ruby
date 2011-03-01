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
  end

  class User < Data; end

  class View < Data
    def columns(params = {})
      return get_request("/views/#{self.id}/columns.json", :query => params)
    end

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

    # Upload a file for a document or photo column
    def upload_file(filename)
      response = multipart_post_file("/views/#{self.id}/files", filename)
      check_error!(response)
      return response
    end
  end
end
