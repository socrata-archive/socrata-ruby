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

    context "Publishers" do
      should "be able to import a new dataset and then delete it" do
        imported_view = @socrata.import("#{File.dirname(__FILE__)}/test_file.csv")
        assert_not_nil imported_view.id

        imported_view.delete!
      end

      context "With an imported dataset" do
        setup do
          @imported_view = @socrata.import("#{File.dirname(__FILE__)}/test_file.csv")
          assert_not_nil @imported_view.id
        end

        should "be able to refresh the dataset" do
          @imported_view.replace("#{File.dirname(__FILE__)}/test_file.csv")
          assert @imported_view.rows.size > 0
        end

        should "be able to push new rows" do
          rows = @imported_view.rows.size

          # Append a new row
          @imported_view.push_row({"Column 1" => 1234, "Column 2" => 5678})
          assert_equal rows + 1, @imported_view.rows.size
        end

        should "be able to truncate a dataset" do
          # Truncate it...
          @imported_view.truncate!

          assert_equal 0, @imported_view.rows.size
        end

        should "be able to append to a dataset" do
          rows = @imported_view.rows.size

          # Append to it
          @imported_view.append("#{File.dirname(__FILE__)}/test_file.csv")
          assert @imported_view.rows.size > rows
        end

        should "be able to update a row" do
          row = @imported_view.push_row({"Column 1" => 1234, "Column 2" => 5678})

          # Update the row
          new_row = @imported_view.update_row(row["_id"], {"Column 1" => 42})
          assert_equal row["_id"], new_row["_id"]
          assert_equal row["_uuid"], new_row["_uuid"]
          assert_equal 42, new_row["column_1"].to_i
        end

        should "be able to perform several row creates in a batch" do
          rows = @imported_view.rows.size

          # Start a batch request
          @imported_view.batch_request do
            @imported_view.push_row({"Column 1" => 1212, "Column 2" => 3434})
            @imported_view.push_row({"Column 1" => 3434, "Column 2" => 4545})
            @imported_view.push_row({"Column 1" => 4545, "Column 2" => 5656})
          end

          assert_equal rows + 3, @imported_view.rows.size
        end

        should "be able to perform several row updates in a batch" do
          rows = @imported_view.rows

          @imported_view.batch_request do
            # Update every row to set column 1 = its row ID
            rows.each do |row|
              @imported_view.update_row(row["_id"], {"Column 1" => row["_id"]})
            end
          end

          # Now check our work
          rows = @imported_view.rows
          rows.each do |row|
            pp row
            assert_equal row["_id"], row["Column 1"].to_i
          end
        end

        teardown do
          @imported_view.delete!
        end
      end
    end
  end
end
