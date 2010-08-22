require 'test_helper'
require 'pp'

class SocrataTest < Test::Unit::TestCase
  context "Util" do
    should "camelize keys correctly" do
      filter = {
        :order_bys => [
          { :ascending => false,
            :expression => {
              :type => "column",
              :column_id => 2354168
            }
          }
        ],
        :filter_condition => {
          :type => "operator",
          :value => "AND",
          :children => [
            { :type => "operator",
              :value => "GREATER_THAN",
              :children => [
                { :type => "column",
                  :column_id => 2354168
                },
                { :type => "literal",
                  :value => 13415141
                }
              ]
            }
          ]
        }
      }

      # Camelize!
      filter = Util.camelize_keys(filter)

      # Confirm that keys have been converted
      filter.each do |key, value|
        assert_kind_of String, key
        assert_nil key.match /_/
      end
    end
  end


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
    should "able to access a user profile by id" do
      chrismetcalf = @socrata.user("i7d8-sc4w")
      assert_equal "Chris Metcalf", chrismetcalf.displayName
      assert_equal "i7d8-sc4w", chrismetcalf.id
    end

    should "not be able to see email address" do
      chrismetcalf = @socrata.user("i7d8-sc4w")
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
    context "with noms view" do
      setup do
        @noms = @socrata.view("n5m4-mism")
      end

      should "be able to get view rows" do
        rows = @noms.rows
        assert rows.size > 0
      end

      should "be able to get rows with a limit" do
        rows = @noms.rows({:max_rows => 5})
        assert_equal 5, rows.size
      end

      should "keys should be column names" do
        rows = @noms.rows({:max_rows => 5})
        rows.each do |row|
          row.each_key {|k| assert_kind_of String, k}
        end
      end

      should "keys should be IDs if requested" do
        rows = @noms.rows({:max_rows => 5}, "id")
        rows.each do |row|
          row.each_key {|k| assert_kind_of Integer, k.to_i}
        end
      end

      should "be able to preform a filter" do
        filter = {
          :order_bys => [
            :ascending => true,
            :expression => {
              :column_id => 2205506,
              :type => "column"
            }
          ],
          :filter_condition => {
            :type => "operator",
            :value => "EQUALS",
            :children => [
              { :type => "column", :column_id => 2205503, :value => "description" },
              { :type => "literal", :value => "CIA" }
            ]
          }
        }

        rows = @noms.filter(filter)
        assert rows.size > 0
      end
    end

  end

  context "Authenticated" do
    setup do
      # Sorry, no password for you! :)
      @socrata = Socrata.new({:username => "chris.metcalf@socrata.com", :password => ENV['SOCRATA_PASSWORD']})
    end

    should "able to see own email address in profile" do
      chrismetcalf = @socrata.user("i7d8-sc4w")
      assert_not_nil chrismetcalf.email
    end
  end
end
