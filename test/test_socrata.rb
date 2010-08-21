require 'test_helper'
require 'pp'

class SocrataTest < Test::Unit::TestCase
  ##################
  # Unauthenticated
  ##################
  context "Unauthenticated" do
    setup do
      @socrata = Socrata.new
    end

    ################
    # User Profiles
    ################
    should "able to access user profile by login" do
      chrismetcalf = @socrata.user("chris.metcalf")
      assert_equal "chris.metcalf", chrismetcalf.login
    end

    should "able to access a user profile by id" do
      chrismetcalf = @socrata.user("i7d8-sc4w")
      assert_equal "chris.metcalf", chrismetcalf.login
      assert_equal "i7d8-sc4w", chrismetcalf.id
    end

    should "not be able to see email address" do
      chrismetcalf = @socrata.user("chris.metcalf")
      assert_nil chrismetcalf.email_address
    end

    ################
    # View Metadata
    ################
    should "be able to get view metadata" do
      noms = @socrata.view("n5m4-mism")
      assert_equal "n5m4-mism", noms.id
      assert_equal "The White House - Nominations & Appointments", noms.name
    end

    ############
    # View Rows
    ############
    should "be able to get view rows" do
      noms = @socrata.view("n5m4-mism")
      rows = noms.rows
      assert rows.size > 0
    end

    should "be able to get rows with a limit" do
      noms = @socrata.view("n5m4-mism")
      rows = noms.rows({:max_rows => 5})

      assert_equal 5, rows.size
    end

    should "keys should be column names" do
      noms = @socrata.view("n5m4-mism")
      rows = noms.rows({:max_rows => 5})

      rows.each do |row|
        row.each_key {|k| assert_kind_of String, k}
      end
    end

    should "keys should be IDs if requested" do
      noms = @socrata.view("n5m4-mism")
      rows = noms.rows({:max_rows => 5}, "id")

      rows.each do |row|
        row.each_key {|k| assert_kind_of Integer, k.to_i}
      end
    end
  end

  context "Authenticated" do
    setup do
      # Sorry, no password for you! :)
      @socrata = Socrata.new({:username => "chrismetcalf-testing", :password => ENV['SOCRATA_PASSWORD']})
    end

    should "able to see own email address in profile" do
      chrismetcalf = @socrata.user("chrismetcalf-testing")
      assert_not_nil chrismetcalf.email
    end
  end
end
