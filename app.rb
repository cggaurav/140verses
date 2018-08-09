require 'sinatra'
require 'newrelic_rpm'
require 'twitter'
require 'ruby_rhymes'
require 'twitter-text'
require 'pony'
require 'redis'
require 'json'

include Twitter::Autolink

$client = Twitter::REST::Client.new do |config|
  config.consumer_key        = "A"
  config.consumer_secret     = "B"
  config.access_token        = "C-D"
  config.access_token_secret = "E"
end

# topics = ["coffee", "tea"]
# client.filter(:track => topics.join(",")) do |tweet|
#   puts tweet.text
# end

Encoding.default_external = "utf-8"
configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end
configure do
  # redis_uri = (ENV["REDISTOGO_URL"])
  redis_uri = (ENV["REDISTOGO_URL"]) || 'redis://A:F@chubb.redistogo.com:G/'
  uri = URI.parse(redis_uri)
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

$words = ["iphone", "Panic", "love", "quote", "guilt", "pleasure",
      "angry", "happy", "sad",  "bored", "hate", "insult", "sex", "valentine", "kim", "justin", "beiber","
      having","then","now","what","nowplaying","coffee","love","hello","world"]

$top10 = ["ubvcddo", "jdjsnme", "ynigkce","tqnamvn","agnljqw"]

def cleanTweet(tweet)
  #remove hashtags,RT,@username, and urls
  tweet = tweet.gsub("RT ","").gsub(": ","").gsub("?","").gsub("\n","").gsub('"',"").gsub("'","").strip.chomp
  tweet = auto_link(tweet).gsub(/.*<a.*<\/a>/,"").strip.chomp.gsub("#","")
  special = [">","<","!","@","{","}","<",">","-","_",":",";","/","\\"]
  clean = true;
  special.each { |i| clean = false if tweet.include? i}
  if( tweet.length >80 or tweet.length < 40 or clean == false)
    nil
  else
    tweet
  end
end

def findTweet(word)
  begin
    $client.search(word, {:lang => 'en', :rpp => 100}).collect  
  rescue Exception => e
    puts e;
    []
  end
end

def poemize(word1,word2)
  word1 = $words.sample.downcase if(word1 == "" or word1 == nil)
  word2 = $words.sample.downcase if(word2 == "" or word2 == nil)

  @first_pair = []
  findTweet(word1).each do |tweet|
    # puts tweet.text
    first = cleanTweet(tweet.text)
    if first and !first.start_with? word1 and !first.end_with? word1
      puts "FIRST1 " + first
      rhymes = first.to_phrase.flat_rhymes.delete_if{|x| x.include? "'"}
      if rhymes!=[]
        rhyme = rhymes.sample
        findTweet(rhyme).each do |nexttweet|
          second = cleanTweet(nexttweet.text)
          if second
            #We are done

            puts "SECOND1 " + second
            @first_pair.push({1 => first, 2=>second, "t1" => tweet.user.screen_name, "t2" => nexttweet.user.screen_name, "s1" => tweet.id, "s2" => nexttweet.id})
            break
          end
        end
      end
    end
  end

  #puts @first_pair.inspect

  @second_pair = []
  findTweet(word2).each do |tweet|
    first = cleanTweet(tweet.text)
    if first and !first.start_with? word2 and !first.end_with? word2
      puts "FIRST2 " + first
      rhymes = first.to_phrase.flat_rhymes.delete_if{|x| x.include? "'"}
      if rhymes!=[]
        rhyme = rhymes.sample
        findTweet(rhyme).each do |nexttweet|
          second = cleanTweet(nexttweet.text)
          if second
            #We are done
            
            puts "SECOND2 " + second
            @second_pair.push({3 => first, 4=>second, "t3" => tweet.user.screen_name, "t4" => nexttweet.user.screen_name, "s3" => tweet.id, "s4" => nexttweet.id})
            break
          end
        end
      end
    end
  end

  #puts @second_pair.inspect
  puts @poem
  @poem = @first_pair.sample.merge(@second_pair.sample) rescue nil
end

get '/' do
  @poems = []
  $top10.each do |key|
    @poems.push(eval(REDIS.get(key)))
  end
  erb :index
end

get '/about' do
  erb :about
end

get '/create' do
  session[:create] = true
  word1 = params[:word1]
  word2 = params[:word2]
  if(word1 == nil and word2 == nil)
    @poems = ""
  else
    @poems = poemize(word1, word2)
    key = (0...7).map{ ('a'..'z').to_a[rand(26)] }.join
    if(@poems)
      puts "HERE_WE_GO"
      puts @poems
      @poems["key"] = key
      url = "http://www.140verses.com/share/" + key
      REDIS.set(key,@poems)
      $client.update("@"+ @poems["t1"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
      $client.update("@"+ @poems["t2"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
      $client.update("@"+ @poems["t3"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
      $client.update("@"+ @poems["t4"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
    end
  end
  erb :create
  #@poems = {1 => "Hello", 2 => "World", 3=>"somtimes I think this should be longer that what it should be and then I worry about what is next, aaaaaaaasdfasdfasdfasdfasfdfasdfasdfasdfsadf", 4=>"a", "t1"=>"cggaurav", "t2" => "nikhilv", "t3" => "140verses", "t4" => "__asf"}
end

get '/discover' do 
  @poems = []
  (0..4).each do |i|
    key = REDIS.randomkey()
    poem = eval(REDIS.get(key))
    poem["key"] = key
    @poems.push(poem) if poem
  end
  erb :discover
end

get '/tweet' do
  $client.update("Welcome to #140verses")
  "Done"
end

get '/flushall' do 
  REDIS.flushall()
end

post '/contact' do
  puts params.inspect
  begin
    Pony.mail(
      :from => params[:email],
      :to => 'nikhil@140verses.com',
      :subject => params[:name] + " has contacted you",
      :body => params[:feedback],
      :port => '587',
      :via => :smtp,
      :via_options => { 
      :address              => 'smtp.sendgrid.net', 
      :port                 => '587', 
      :enable_starttls_auto => true, 
      :user_name            => ENV['SENDGRID_USERNAME'], 
      :password             => ENV['SENDGRID_PASSWORD'], 
      :authentication       => :plain, 
      :domain               => ENV['SENDGRID_DOMAIN']
    })  
    redirect '/contact?status=true'
  rescue Exception => e
    redirect '/contact?status=false'
  end
end

get '/contact' do
  @status = params[:status]
  erb :contact
end

get '/top10/:id' do
  key = params[:id]
  $top10.unshift(key) if REDIS.exists(key)
end


get '/share/:id' do 
  key = params[:id].to_s
  begin
    @poem = eval(REDIS.get(key))  
    url = "http://www.140verses.com/share/" + key
    if(session[:create] == true)
      $client.update("@"+ @poem["t1"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
      $client.update("@"+ @poem["t2"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
      $client.update("@"+ @poem["t3"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
      $client.update("@"+ @poem["t4"] + " ,We just composed a poem using your tweet at #140verses, take a look at #{url}") rescue nil
    end
    erb :share
  rescue Exception => e
    erb :notfound
  end
end

not_found do 
  erb :notfound
end