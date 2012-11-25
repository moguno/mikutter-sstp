# -*- coding: utf-8 -*-
 
require 'date'


# IDからシンボルを作る
def sym(base, id)
  (base + id.to_s).to_sym
end


class SSTP
  METHODS = {
    :send11 => ["SEND", "1.1"]
  }

  def initialize(ip_addr, port)
    @ip_addr = ip_addr
    @port = port
    @mutex = Mutex.new
  end

  def send11(script)
    requests = []

    requests << [:Sender, "moguno"]
    requests << [:Event, "OnRelease"]
    requests << [:Script, script.to_s]
    requests << [:ption, 'notranslate']
    requests << [:Charset, "UTF-8"]

    request(:send11, requests)
  end

  def request(method, headers)
    Thread.new {
      @mutex.synchronize {
        requests = []
        requests << METHODS[method][0] + " SSTP/" + METHODS[method][1]

        headers.each { |v|
          requests << v[0].to_s + ": " + v[1].to_s
        }

        request = requests.join("\r\n") + ("\r\n" * 2)

        TCPSocket.open(@ip_addr, @port) { |sock|
          sock.write(request)
          p sock.read(4096)
          sock.close
        }
      }
    }
  end
end


class SSTPScript

  def initialize(bless_wait = 300, br_wait = 1500)
    @bless_wait = bless_wait
    @br_wait = br_wait
    @script = ""
  end

  def miku!(clear = true, &block)
    result = block.call(self) 
    if clear then
      @script.concat('\0\c' + result + '\n')
    else
      @script.concat('\0' + result + '\n')
    end
  end

  def toshi_a!(clear = true, &block)
    result = block.call(self) 

    if clear then
      @script.concat('\1\c' + result + '\n')
    else
      @script.concat('\1' + result + '\n')
    end
  end

  def wait(ms)
    '\_w[' + ms.to_s + ']'
  end

  def skin(no)
    '\s[' + no.to_s + ']'
  end

  def bless(bless_wait = @bless_wait)
    wait(bless_wait)
  end

  def br(br_wait = @br_wait)
    wait(br_wait) + '\n'
  end

  def silent
    '\b[-1]'
  end

  def yukkuri(words, bless_wait = @bless_wait)
    words.inject("") { |result, word|
      result + word + bless(bless_wait)
    }
  end
   
  def to_s()
    @script + '\e'
  end
end


# 検索クラス
class Toshi_a
  attr_reader :last_fetch_time


  def initialize(service)
    @service = service
    @queue_lock = Mutex.new
    @result_queue = []
  end


  # 日時文字列をパースする
  def parse_time(str)
    begin
      if str.class == Time then
        str
      else
        Time.parse(str)
      end
    rescue
      nil
    end
  end


  # 検索結果を取り出す
  def fetch()
    msg = nil

    @queue_lock.synchronize {
      msg = @result_queue.shift
    }

    if msg != nil then
      @last_fetch_time = Time.now
    end 

    # puts @keywords.to_s + @result_queue.size.to_s

    return msg
  end


  # メッセージ保有してる？
  def empty?()
   @result_queue.empty?
  end


  # 検索する
  def search()
    keyword = "toshi_a"

    query_keyword = keyword.strip.rstrip.sub(/ +/,"+")
  
    if query_keyword.empty? then
      return
    end
  
    params = {}

    query_tmp = query_keyword + "+-rt+-via"

    if @last_result_time != nil then
      query_tmp = query_tmp + "+since:" + @last_result_time.strftime("%Y-%m-%d")
    end
  
    params[:q] = query_tmp

    params[:rpp] = 500.to_s

    if query_keyword.empty? then
      return
    end
  
    params[:lang] = "ja"

    @service.search(params).next{ |res| 
      begin
        res = res.select { |es|
          result_tmp = false

          if es[:created_at].class == String then
            tim = parse_time(es[:created_at]) 
          else
            p "mulformed created_at:"
            p es.class
            p es

            tim = nil
          end

          reply = es.receive_message

          if !(es[:message] =~ /^RT /) then
            result_tmp2 = false

            if es[:user] != nil then
              if es[:user][:idname] == "toshi_a"
                result_tmp2 = true
              end

              if result_tmp2 then
                if @last_result_time == nil then
                  result_tmp = true
                elsif tim != nil && @last_result_time < tim then
                  result_tmp = true
                end
              end
            end
          end

          result_tmp
        }

        if res.size == 0 then
          next
        end
  
        res.each { |es| 
          # 一回アクセスしてキャッシュさせる
          reply = es.receive_message

          tim = parse_time(es[:created_at])
  
          if tim != nil && (@last_result_time == nil || @last_result_time < tim) then
            @last_result_time = tim
          end
        }
  
        # p "new message:" + res.size.to_s
        # p "last time:" + $last_time.to_s
  
        @queue_lock.synchronize {
          # puts @keywords.to_s + res.size.to_s
          @result_queue.concat(res.reverse)
        }
      rescue => e
        puts e
        puts e.backtrace
      end
    }
  end
end
  

Plugin.create :sstp do 
  
  # グローバル変数の初期化
  $toshi_a = nil


  def boot_message()
    script = SSTPScript.new

    script.miku! { |s|
      "こんにちわマスター。" + s.br +
      "私はミク。" + s.br +
      "みくった〜のミク要素を、" + s.bless + "「ておくれていない」皆さんにも" + s.bless +
      "分かるように可視化されたのがワタシです。" + s.br
    }

    script.miku! { |s|
      "そしてこちらが" + s.br
    }

    script.toshi_a! { |s|
      "ぴやぁぁぁぁぁぁぁぁぁぁぁ！" + s.br +
      s.silent
    }

    script.miku!(false) { |s|
      s.yukkuri(["・", "・", "・"]) + s.bless + "toshi_aさんですよね？" + s.br
    } 

    script.toshi_a! { |s|
      s.yukkuri(["垢消せ！", "垢消せ！"]) + s.br +
      s.silent
    }

    script.miku! { |s|
      s.yukkuri(["え", "え", "と、", "多分", "・", "・", "・"]) + s.bless + "みくった〜の作者、toshi_aさんです。" + s.br +
      s.silent
    }

    script.toshi_a! { |s|
      "ぴやぁぁぁぁぁぁぁぁぁぁぁ！" + s.br +
      s.silent
    }

    script
  end


  # 検索用ループ
  def search_loop(service)
      search_keyword(service) 

    Reserver.new(UserConfig[:sstp_period]){
      search_loop(service)
    } 
  end
  

  # 混ぜ込みループ
  def insert_loop(service)
    begin
      if !$toshi_a.empty? then
        msg = $toshi_a.fetch

        script = SSTPScript.new()

        reply = msg.receive_message

        if reply != nil then
          script.miku! { |s|
            "toshi_aさん、" + s.bless + reply[:user][:name] + "さんがこんなこと言ってたよ。" + s.br + s.br +
            msg.receive_message[:message].gsub(/[\r\n]/, '\n') + s.br
          } 
        end

        script.toshi_a! { |s|
          msg[:message].gsub(/[\r\n]/, '\n') + s.br + 
          s.wait(3000)
        } 

        if reply != nil then
          script.miku!(false) { |s|
            s.silent
          } 
        end

        script.toshi_a! { |s|
          s.silent
        } 

        $sstp.send11(script)
      end

      Reserver.new(UserConfig[:sstp_insert_period]){
        insert_loop(service)
      } 
        
    rescue => e
      puts e
      puts e.backtrace
    end
  end


  # 検索
  def search_keyword(service)
    begin
      $toshi_a.search()
    rescue => e
      puts e
      puts e.backtrace
    end
  end


  # 起動時処理
  on_boot do |service|
    $toshi_a = Toshi_a.new(service)

    $sstp = SSTP.new("localhost", 9801)

    $sstp.send11(boot_message)

    # コンフィグの初期化
    UserConfig[:sstp_period] ||= 60
    UserConfig[:sstp_insert_period] ||= 20

    # 設定画面
    settings "SSTP" do
      adjustment("ポーリング間隔（秒）", :sstp_period, 1, 6000)
      adjustment("混ぜ込み間隔（秒）", :sstp_insert_period, 1, 600)
    end 

    search_loop(service)
    insert_loop(service)
  end
end
