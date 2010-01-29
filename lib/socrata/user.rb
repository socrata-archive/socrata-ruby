module Socrata
  class User < SocrataAPI
    def initialize(params = {})
      @user = params[:username]
      raise ArgumentError, 'No username specified' if @user.nil?
      super
    end
    
    def datasets
      sets = []
      self.class.get("/users/#{@user}/views.json").each do |set|
        dataset = Dataset.new(:config => @config)
        dataset.attach(set['id'])
        sets << dataset
      end
      sets
    end
    
    def profile
      self.class.get("/users/#{@user}.json")
    end
  end
end