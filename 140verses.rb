require 'rubygems'
require 'twitter'
require 'ruby_rhymes'
require 'twitter-text'
include Twitter::Autolink

def cleanTweet(tweet)
  #remove hashtags,RT,@username, and urls
  
  tweet = tweet.gsub("RT ","").gsub(": ","").gsub("?","").gsub("\n","")
  tweet = auto_link(tweet).gsub(/.*<a.*<\/a>/,"").strip.chomp
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
  Twitter.search(word, {:lang => 'en', :rpp => 50}).results
end

def poemize(word1="having",word2="then")
	@first_pair = []
	findTweet(word1).each do |tweet|
	  first = cleanTweet(tweet.text)
	  if first and !first.start_with? word1 and !first.end_with? word1
	    rhymes = first.to_phrase.flat_rhymes.delete_if{|x| x.include? "'"}
	    if rhymes!=[]
	      rhyme = rhymes.sample
	      findTweet(rhyme).each do |nexttweet|
	        second = cleanTweet(nexttweet.text)
	        if second and second.end_with? rhyme
	          #We are done
	          @first_pair.push({1 => first, 2=>second, "t1" => tweet.from_user, "t2" => nexttweet.from_user})
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
	    rhymes = first.to_phrase.flat_rhymes.delete_if{|x| x.include? "'"}
	    if rhymes!=[]
	      rhyme = rhymes.sample
	      findTweet(rhyme).each do |nexttweet|
	        second = cleanTweet(nexttweet.text)
	        if second and second.end_with? rhyme
	          #We are done
	          @second_pair.push({3 => first, 4=>second, "t3" => tweet.from_user, "t4" => nexttweet.from_user})
	          break
	        end
	      end
	    end
	  end
	end
	begin
		@poems = @first_pair.sample.merge(@second_pair.sample)	
	rescue Exception => e
		nil
	end
end

puts poemize("love","hate")

