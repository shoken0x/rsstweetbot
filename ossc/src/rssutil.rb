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
  # feedの取得
  feed = RSS::Parser.parse(RBatch::config["rss_url"])
  if ! feed.instance_of?(RSS::Atom::Feed)
    log.error("this is not instance of RSS::Atom::Feed")
    exit 1
  end
  # 最後の行をlastupdateに格納。ファイルが空なら2000/1/1にする
  lastupdate = "2000-01-01T00:00:00Z"
  file = open(RBatch::config["lastupdate_file"], "r+")
  file.each {|line| lastupdate = line}
  #feed.itemsをpublishedでsort
  feed.items.sort! {|a,b|
    Time.parse(a.published.to_s) <=> Time.parse(b.published.to_s)
  }
  #feedに対するメイン処理
  feed.items.each do |item|
    next if(Time.parse(item.published.to_s) <= Time.parse(lastupdate))
    title     = item.title.to_s.gsub("<title>","").gsub("</title>","")
    published = item.published.to_s.gsub("<published>","").gsub("</published>","")
    link      = item.link.to_s.gsub(/<link href="/,'').gsub(/".*/m,'')
    next if /^\*/ =~ title  #*(アスタリスク)で始まる更新はtweetしない
    stime = Time.parse(published).strftime("%Y年%m月%d日")
    # urlに40文字,更新日付に15文字,ハッシュタグに30文字確保、
    hashtag = RBatch::config["twitter"]["hashtag"]
    cut_num = 50
    if (title.include?('OpenAM'))
      #titleにOpenAMが入っていたらハッシュタグに#openam_jpを追加
      hashtag = hashtag + ' #openam_jp'
      cut_num = 40
    end
    # タイトルがcut_num以上だったら...にする
    if (title.size > cut_num)
      title = title[0..cut_num - 6] + "...  "
    end
    #&amp;,&lt;,&gt;を&,<,>に変換する
    tweet_str = CGI.unescapeHTML("#{title} : #{link}: #{stime}更新 #{hashtag} ")
    begin
      Twitter.configure do |config|
        config.consumer_key       = RBatch::config["twitter"]["consumer_key"]
        config.consumer_secret    = RBatch::config["twitter"]["consumer_secret"]
        config.oauth_token        = RBatch::config["twitter"]["oauth_token"]
        config.oauth_token_secret = RBatch::config["twitter"]["oauth_token_secret"]
      end
      Twitter.update(tweet_str)
      log.info(published + tweet_str)
      #ツイートできた更新の時刻を書き込む
      file.write published + "\n"
      break # 一回つぶやいたら終わり
    rescue Exception => e
      log.error(e)
    end # end begin
  end # end feed.items.each
  file.close
end
