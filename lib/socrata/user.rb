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

#module Socrata
  #class User < SocrataAPI
    #def initialize(params = {})
      #@user = params[:username]
      #raise ArgumentError, 'No username specified' if @user.nil?
      #super
    #end
    
    #def datasets
      #sets = []
      #self.class.get("/users/#{@user}/views.json").each do |set|
        #dataset = Dataset.new(:config => @config)
        #dataset.attach(set['id'])
        #sets << dataset
      #end
      #sets
    #end
    
    #def profile
      #self.class.get("/users/#{@user}.json")
    #end
  #end
#end
