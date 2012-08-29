#!/usr/local/bin/ruby
# encoding: utf-8

require 'logger'
require 'rss'
require 'time'
require 'twitter'

#logger
@@log = Logger.new('/var/log/moe3_01.log','monthly')
@@log.level = Logger::INFO


ENV["TZ"] = 'Asia/Tokyo'
url = ''
cutoff_date = '2012-04-01T07:15:14Z'
@@hashtag = ''


def print_items(feed)
  title = Array.new
  published = Array.new
  link = Array.new
  a_title = ''
  a_published = ''
  a_link = ''

  lastupdate = ''
  f = open('/root/src/moe3_01/lastupdate', 'r+')
  f.each {|line| lastupdate = line}
  if lastupdate == ''
    lastupdate = cutoff_date
  end
  
  if feed.instance_of?(RSS::Atom::Feed)
    @@log.debug('Atom ')

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
    

  elsif feed.instance_of?(RSS::Rss)
    @@log.debug('RSS ')

    feed.items.sort! {|a,b|
      @@log.debug(a.pubDate.to_s)
      Time.parse(a.pubDate.to_s) <=> Time.parse(b.pubDate.to_s)
    }
    feed.items.each do |item|
      if(Time.parse(item.pubDate.to_s) > Time.parse(lastupdate))
        @@log.debug(item.title.to_s)
        title << item.title.to_s
        @@log.debug(item.pubDate.to_s)
        published << item.pubDate.to_s
        @@log.debug(item.link.to_s)
        link << item.link.to_s.gsub(/<link href="/,'').gsub(/".*/m,'')
      end
    end 
  end
  #elsif feed.instance_of?(RSS::RDF)
  #  feed.items.each do |item|
  #    puts "#{item.title} : #{item.date.strftime("%Y-%m-%d %H:%M:%S")}"
  #  end 
  #end 
  
  #TODO
  #Atomならxmlからのconvert処理が必要
  a_title = title
  a_published = published
  a_link = link

  title.size.times do |i| 
    t = Time.parse(a_published[i])
    stime = t.strftime("%Y年%m月%d日")
    
    @@log.debug(a_title[i])
    @@log.debug(a_link[i])

    #test
    #a_title[i] = Time.now.strftime('%Y%m%d%H%M%S%3N')
    #a_link[i] = 'http://example.com/test'

    # urlに40文字,更新日付に15文字確保し、タイトルが70文字以上だったらカットする
    cut_num = 70 
    if (a_title[i].size > cut_num)
      a_title[i] = slice_by_length(a_title[i], cut_num - 5)
      a_title[i] << '...  '
    end

    tweet_str = "#{a_title[i]} #{a_link[i]} #{stime}更新"

    begin
      tweet(tweet_str)
      @@log.info(tweet_str)
    rescue Exception => e
      @@log.error(e)
    end
  end 

  #最新記事のpublishedをファイルへ保存
  if(a_published.size > 0)
    a_published.sort!
    #a_published.reverse!
    f.write a_published[0] + "\n"
  end
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
    #moe3_001
    config.consumer_key = ''
    config.consumer_secret = ''
    config.oauth_token = ''
    config.oauth_token_secret = ''
  end
  Twitter.update( str )
end

rss = RSS::Parser.parse(url)
print_items(rss)


