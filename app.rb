Shoes.setup do
  gem "twitter"
end

require "config.rb"
require "twitter"
require "yaml"
require "cgi"

class Settings
  @@data = nil
  
  def self.load
    return if @@data
    
    if File.exist? $TwitterShoesConfig[:settings_yaml]
      @@data = Yaml.load_file $TwitterShoesConfig[:settings_yaml]
    else
      @@data = {}
    end
  end
  
  def self.get(key)
    @@data[key]
  end
  
  def self.set(key,value)
    @@data[key] = value
  end
  
  def self.save
    File.open( $TwitterShoesConfig[:settings_yaml],"w") do |out|
      out.puts @@data.to_yaml
    end
  end
end

class TwitterShoes < Shoes
  
  url "/", :index
  url "/update", :update
  url "/home", :home
  url "/favourites", :favourites
  
  
  def parse_tweet(tweet)
    parts = []
    counter = 0
    specials = tweet.scan(/(^|\s+)((https?\:\/\/\S+[^\.\s+])|(\@[a-zA-Z0-9_]{1,15})|(\#[a-zA-Z0-9_]+))/)
    specials.each do |special|
      actual = special[1]
      space = ""
      idx = tweet.index(actual)
      parts.push space+tweet.slice(0,idx)
      special_link = link tweet.slice(idx,actual.length)
      special_link.click { visit actual } if not special[2].nil?
      special_link.click { visit "http://twitter.com/"+CGI.escape(actual.slice(1,actual.length)) } if not special[3].nil?
      special_link.click { visit "http://search.twitter.com/search?q="+CGI.escape(actual.slice(1,actual.length))} if not special[4].nil?
      parts.push special_link
      tweet = tweet.slice(idx+actual.length, tweet.length)
    end
    parts.push tweet
    parts
  end
  
  def show_tweet(tweet)
    myflow = flow do 
      image tweet.user.profile_image_url, :height => 32, :width => 32
      stack :width => -40 do
        username = tweet.user.screen_name
        inscription link(username, :click => "http://twitter.com/#{username}"), "\n", parse_tweet(tweet.text)
      end
    end
  end
  
  def styles(key)
    case key
    when :body
      background palegreen
      border limegreen, :strokewidth => 5
    when :main
      return {
        :margin => 10
      }
    end
  end
  
  def main 
    styles :body
    stack(styles :main) do
      flow do
        button "Home" do visit "/home" end
        button "Update" do visit "/update" end
        button "Favourites" do visit "/favourites" end
        button "twitter.com", :right => 10 do visit "http://twitter.com/" end
      end
      yield
    end
  end
  
  def index
    oauth = Twitter::OAuth.new(
      $TwitterShoesConfig[:twitter_consumer_key],
      $TwitterShoesConfig[:twitter_consumer_secret]
    )
    
    Settings.load
    if(Settings.get :access_token )
      oauth.authorize_from_access(
        Settings.get(:access_token),
        Settings.get(:access_secret)
      )
      @@twitter = Twitter::Base.new(oauth)
      visit "/home"
    end
    rt = nil
    styles :body
    stack(styles :main) do
      para "1. Authorize your Twitter account: "
      button "Launch Twitter in browser" do
        rt = oauth.request_token()
        visit "http://twitter.com/oauth/authorize/?oauth_token="+rt.token
      end
      para "2. Enter the PIN from Twitter:"
      verify_code = edit_line
      para
      button "Verify PIN" do
        oauth.authorize_from_request(rt.token,rt.secret,verify_code.text())
        Settings.set(:access_token,oauth.access_token.token)
        Settings.set(:access_secret,oauth.access_token.secret)
        Settings.save
        @@twitter = Twitter::Base.new(oauth)
        visit "/home"
      end
    end
  end
  
  def home
    main do
      @@twitter.home_timeline.each do |tweet|
        show_tweet tweet
      end
    end
  end
  
  def favourites
    main do
      @@twitter.favorites.each do |tweet|
        show_tweet tweet
      end
    end
  end
  
  def update
    main do
      para "Update your status."
      status = edit_line :width => 0.9
      button "Update status" do
        @@twitter.update(status.text())
        status.text = ""
      end
    end
  end
end

Shoes.app :title => "Tweetweebox"