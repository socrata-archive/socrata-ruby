#!/usr/bin/env ruby
#
# == Synopsis
#
# twitter_set: generates a socrata dataset from a twitter search
#
# == Usage
#
# twitter_set [OPTIONS]
#
# -h, --help:
#   show help
# 
# -r, --results:
#   how many tweets to put in the dataset
#
# -q, --query:
#   what to search twitter for
#


require 'getoptlong'
require 'rdoc/usage'
require 'tempfile'

require 'rubygems'

require 'socrata'

require 'twitter'
require 'curb'


class TwitterSet
  def initialize(query, limit)
    @query = query
    @base = "http://twitter.com/"
    @num_results = limit
    @pictures = {}
  end
  
  #Run the query against Twitter's API
  def search(post_now = false)
    self.create_dataset if @dataset.nil?
    
    puts "Searching for #{@query}"
    results = nil
    unless @num_results.nil?
      results = Twitter::Search.new(@query).per_page(@num_results)
    else
      results = Twitter::Search.new(@query)
    end
    
    results.each do |r|
      self.add_tweet(r)
    end
    # Sort chronological, not reverse- as Twitter API returns it
    # Then turn them into an array of batch requests for the core server
    @rows.reverse!.map! {|r| @dataset.get_add_row_request(r)} unless @rows.nil? || @rows.empty?
    if post_now
      @dataset.batch_request(@rows)
    else
      return @rows
    end
  end
  
  # Marks as public, if it isn't already
  def mark_as_processed
    @dataset.set_public
  end
  
  def create_if_blank(json)
    if @dataset.has_columns?
      # Figure out what the last (largest) twitter id was
      @existing_rows = @dataset.get_rows['data'].map {|r| r[@@tweetid_location]}
      @since_id = @existing_rows.max
    else
      self.setup_columns
    end
  end
  
  def create_dataset
    @dataset = Socrata::Dataset.new if @dataset.nil?
    resp = @dataset.create("'#{@query}' twitter set", '', ['twitter', @query]) unless @dataset.attached?
    if resp == false && !@dataset.attached?
      puts "Failed to create dataset. Check logs"
      return false
    end
    self.setup_columns
    return true
  end
  
  def setup_columns
    return if @dataset.nil? || !@dataset.attached?
    
    @dataset.add_column('Date/Time', nil, 'date', false, false, 128)
    @dataset.add_column('Avatar', nil, 'photo', false, false, 50)
    @dataset.add_column('Sender', nil, 'url', false, true)
    @dataset.add_column('tweet', nil, 'text', false, true, 350)
    @dataset.add_column('URL', nil, 'url', false, true)
    @dataset.add_column('tweetid', 'twitter id', 'text', true)
  end
  
  def add_tweet(t)
    @rows = Array.new if @rows.nil?
    data = {
      'Date/Time' => @dataset.parse_date(t.created_at),
      :Sender => self.link_to(self.get_username_link(t.from_user), t.from_user),
      :tweet => self.linkify(t.text),
      :URL => self.link_to(self.get_status_link(t), 'Status'),
      :Avatar => self.avatar_for(t.from_user),
      :tweetid => t.id.to_s
    }
    @rows << data
  end
  
  def download_avatar(twitter_name)
    file = Tempfile.new(self.class.to_s)
    filename = file.path
    Curl::Easy.download("http://twivatar.org/#{twitter_name}", filename) { |curl| curl.follow_location = true }
    filename
  end
  
  def avatar_for(user)
    @avatars = {} if @avatars.nil?
    # Check to see if we already got a profile pic
    return @avatars[user] if @avatars.has_key?(user)
    image_name = self.download_avatar(user)
    image_id = @dataset.upload_image(image_name)
    
    # Delete the file now that we're done with it
    File.unlink(image_name)
    
    @avatars[user] = image_id
    return image_id
  end
  
  # Given a string, scan it for links and replace those with <a href=...>...</a>
  def linkify(text)
    s = text.to_s
    s.gsub!( @@generic_URL_regexp, '\1<a href="\2">\2</a>' )
    s.gsub!( @@starts_with_www_regexp, '\1<a href="http://\2">\2</a>' )
    s.gsub!( @@hashtag_regexp, self.color_text('<a href="http://twitter.com/search?q=%23\1">#\1</a>') )
    s.gsub!( @@atuser_regexp, self.color_text('<a href="http://twitter.com/\1">@\1</a>', 'blue') )
    return s
  end
  
  def color_text(text, color = "#ff0000")
    "<span style=\"color: #{color};\">#{text}</span>"
  end
  
  def link_to(link, title)
    "<a href='#{link}'>#{title}</a>"
  end
  
  def get_link
    @dataset.link_url(:name => 'Socrata-Tweetset', :category => 'Fun') if @dataset.attached?
  end
  
  def get_status_link(tweet)
    "#{@base}#{tweet['from_user']}/statuses/#{tweet['id']}"
  end
  
  def get_username_link(name)
    "#{@base}#{name}"
  end
  
  
  @@generic_URL_regexp = Regexp.new( '(^|[\n ])([\w]+?://[\w]+[^ \"\n\r\t<]*)', Regexp::MULTILINE | Regexp::IGNORECASE )
  @@starts_with_www_regexp = Regexp.new( '(^|[\n ])((www)\.[^ \"\t\n\r<]*)', Regexp::MULTILINE | Regexp::IGNORECASE )
  @@hashtag_regexp = Regexp.new( '#([^ ,.;:\"\t\n\r<]*)', Regexp::MULTILINE | Regexp::IGNORECASE )
  @@atuser_regexp = Regexp.new( '@([^ ,.;:\"\t\n\r<]*)', Regexp::MULTILINE | Regexp::IGNORECASE )
end


opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--results', '-r', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--query', '-q', GetoptLong::OPTIONAL_ARGUMENT]
)

query = nil
num_results = nil

opts.each do |opt, arg|
  case opt
    when '--help'
      RDoc::usage
    when '--query'
      query = arg
    when '--results'
      num_results = arg
    when '--update'
      update = true
      daemon = false
  end
end

if query.nil?
  RDoc::usage
end

set = TwitterSet.new(query, num_results)
set.search(true)
puts "Finished:\n#{set.get_link}"

