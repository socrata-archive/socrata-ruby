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

    def get_row(row_id)
      return get_request("/views/#{self.id}/rows/#{row_id}.json")
    end

    def filter(filter = {})
      inline = {
        :name => "Inline Filter for #{self.id}",
        :id => self.id,
        :original_view_id => self.id,
        :query => filter
      }

      return post_request("/views/INLINE/rows.json?method=index", 
                          {:body => Util.camelize_keys(inline).to_json} )["data"]
    end
  end
end

