#!/usr/local/bin/ruby -Ku
# encoding: utf-8

require 'logger'
require 'rss'
require 'time'
require 'cgi'
require 'rbatch'

gem "twitter","2.2.0"
require 'twitter'

RBatch::Log.new do |log|

  ENV["TZ"]  = RBatch::config["timezone"]
  url        = RBatch::config["rss_url"]
  hashtag    = RBatch::config["twitter"]["hashtag"]
  lastupdate = "2000-01-01T00:00:00Z"
  
  feed = RSS::Parser.parse(url)
  file = open(RBatch::config["lastupdate_file"], "r+")
  # 最後の行をlastupdateに格納
  file.each {|line| lastupdate = line}
  
  if ! feed.instance_of?(RSS::Atom::Feed)
    puts "this is not instance of RSS::Atom::Feed"
    exit 1
  end
  
  #feed.itemsをpublishedでsort
  feed.items.sort! {|a,b|
    Time.parse(a.published.to_s) <=> Time.parse(b.published.to_s)
  }
  
  tweets = []
  feed.items.each do |item|
    if(Time.parse(item.published.to_s) > Time.parse(lastupdate))
      tweets << { 
        :title => item.title.to_s.gsub("<title>","").gsub("</title>",""),
        :published => item.published.to_s.gsub("<published>","").gsub("</published>",""),
        :link => item.link.to_s.gsub(/<link href="/,'').gsub(/".*/m,'')
      }
    end
  end
  
  tweets.each do |tw|
    next if /^\*/ =~ tw[:title]  #*(アスタリスク)で始まる更新はtweetしない
    stime = Time.parse(tw[:published]).strftime("%Y年%m月%d日")
    # urlに40文字,更新日付に15文字,ハッシュタグに30文字確保、
    cut_num = 50
    if (tw[:title].include?('OpenAM'))
      #titleにOpenAMが入っていたらハッシュタグに#openam_jpを追加
      hashtag = hashtag + ' #openam_jp'
      cut_num = 40
    end
    # タイトルがcut_num以上だったら...にする
    if (tw[:title].size > cut_num)
      tw[:title] = tw[:title].split(//).first(cut_num - 5).inject("") do |result, char|
        result += char
      end
      tw[:title] << '...  '
    end
    #&amp;,&lt;,&gt;を&,<,>に変換する
    tweet_str = CGI.unescapeHTML("#{tw[:title]} : #{tw[:link]}: #{stime}更新 #{hashtag} ")
    begin
      Twitter.configure do |config|
        config.consumer_key       = RBatch::config["twitter"]["consumer_key"]
        config.consumer_secret    = RBatch::config["twitter"]["consumer_secret"]
        config.oauth_token        = RBatch::config["twitter"]["oauth_token"]
        config.oauth_token_secret = RBatch::config["twitter"]["oauth_token_secret"]
      end
      Twitter.update(tweet_str)
      log.info(tw[:published] + tweet_str)
      #ツイートできた更新の時刻を書き込む
      file.write tw[:published] + "\n"
      break # 一回つぶやいたら終わり
    rescue Exception => e
      log.error(e)
    end # end begin
  end # end title.times
  file.close
end
