#!/usr/bin/spec

require 'rubygems'
require 'socrata'

describe Socrata::SocrataAPI do
  before(:all) do
    @API = Socrata::SocrataAPI.new(:mode => 'testing')
    @config = @API.config
  end
  
  before(:each) do
    @dataset = Socrata::Dataset.new(:config => @config)
  end
  
  it "should create a new dataset with random name" do
    @rand_name = (0..8).map{65.+(rand(25)).chr}.join
    @rand_name.should_not be_nil, "Should be a random string"
    
    @dataset.create("Test dataset #{@rand_name}")
    @dataset.error.should be_nil, "Should not get an error trying to create a new dataset"
    
    @dataset.attached?.should_not be_false, "Should have a valid ID after creation"
    
    @dataset.delete
  end
  
  it "should not attach allow two datasets of the same name" do
    @dataset.create("Duplicate: #{@rand_name}")
    @dataset.error.should be_nil, "Should be able to create a unique set with random name"
    
    lambda { @dataset.create("Duplicate: #{@rand_name}") }.should raise_error(Exception)
  end
end