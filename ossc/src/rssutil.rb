#!/usr/local/bin/ruby
# encoding: utf-8

require 'logger'
require "rss"
require "time"
require 'twitter'

#logger
@@log = Logger.new('/var/log/oss_info.log','monthly')
#@@log = Logger.new(STDOUT)
@@log.level = Logger::INFO

ENV["TZ"] = "Asia/Tokyo"
url = ""
@@hashtag = ''


def print_items(feed)
  lastupdate = ""
  f = open("/root/src/ruby/lastupdate", "r+")
  f.each {|line| lastupdate = line}
  
  if feed.instance_of?(RSS::Atom::Feed)
    title = Array.new
    published = Array.new
    link = Array.new

    #feed.itemsをpublishedでsort
    feed.items.sort! {|a,b|
      Time.parse(a.published.to_s) <=> Time.parse(b.published.to_s)
    }

    feed.items.each do |item|
      if(Time.parse(item.published.to_s) > Time.parse(lastupdate))
        title << item.title.to_s
        published << item.published.to_s
        link << item.link.to_s.gsub(/<link href="/,'').gsub(/".*/m,'')
      end
    end 
    
    a_title = get_xml_cont(title)
    a_published = get_xml_cont(published)
    a_link = link

    title.size.times do |i| 
      t = Time.parse(a_published[i])
      stime = t.strftime("%Y年%m月%d日")

      #test
      #a_title[i] = 'urlに40文字,更新日付に15文字,ハッシュタグに30文字確保、タイトルが50文字以上だったらカットする'
      #a_link[i] = 'http://example.com'
      #stime = ''

      # urlに40文字,更新日付に15文字,ハッシュタグに30文字確保、タイトルが50文字以上だったらカットする
      cut_num = 50

      #titleにOpenAMが入っていたらハッシュタグに#openam_jpを追加
      if (a_title[i].include?('OpenAM'))
        @@hashtag << ' #openam_jp'
        cut_num = 40
      end

      if (a_title[i].size > cut_num)
        a_title[i] = slice_by_length(a_title[i], cut_num - 5)
        a_title[i] << '...  '
      end
      
      #TODO
      #&amp;,&lt;,&gt;を&,<,>に変換する
      tweet_str = "#{a_title[i]} : #{a_link[i]}: #{stime}更新 #{@@hashtag} "

      begin
        tweet(tweet_str)
        @@log.info(tweet_str)
        #1回の起動で1tweetのみ実行
        f.write a_published[i] + "\n"
        break
      rescue Exception => e
        @@log.error(e)
      end
    end 

    #最新記事のpublishedをファイルへ保存
#    if(a_published.size > 0)
#      a_published.sort!
#      a_published.reverse!
#      f.write a_published[0] + "\n"
#    end

  end
  #elsif feed.instance_of?(RSS::Rss)
  #  feed.items.each do |item|
  #    puts "#{item.title} : #{item.pubDate.strftime("%Y-%m-%d %H:%M:%S")}"
  #  end 
  #elsif feed.instance_of?(RSS::RDF)
  #  feed.items.each do |item|
  #    puts "#{item.title} : #{item.date.strftime("%Y-%m-%d %H:%M:%S")}"
  #  end 
  #end 
  f.close
end

def slice_by_length(str, str_length)
  str.split(//).first(str_length).inject("") do |result, char|
    result += char
  end
end

def get_xml_cont(arr)
  ret = Array.new
  arr.each do |elem|
    %r|<.+>(.*)</.+>| =~ elem
    ret << $1
  end
  ret
end

def tweet(str)
  Twitter.configure do |config|
    #oss_info
    config.consumer_key = ''
    config.consumer_secret = ''
    config.oauth_token = ''
    config.oauth_token_secret = ''
  end
  Twitter.update( str )
end

rss = RSS::Parser.parse(url)
print_items(rss)


