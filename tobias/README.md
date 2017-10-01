# CryatalのWeb Framework

## はじめに
Crystalにも多くのWebフレームワークがあります。

* amber  
  同じCrystalのフレームワークであるKemalやRails、ElixirのPhoenixなど多くのフレームワークから良いところを取り入れつつ、Crystalらしさを重視しているフレームワークです。

* amethyst  
  Railsから強い影響を受けたフレームワークです。2017年になってからcrystal-communityが管理しています。

* kemal  
  高速でシンプルなフレームワークで、GithubでのStar数がCrystalのフレームワークの中では最も多く開発も活発に行われています。

* luckyframework
  2017年になってから開発がスタートしたフレームワークで、まだ初期段階にあるフレームワークです。CLIやORMなどのプロジェクトもあり、issueにTODOが溜められていて今後に期待のフレームワークです。

* raze  
  Middlewareと呼ばれる部分を中心にしたフレームワークで、スポンサーのQualtrics社がproductionで使用しているようです。また、@thrandさんのベンチマーク（ https://github.com/tbrand/which_is_the_fastest ）でも高いパフォーマンスが出ています。

また、関連するライブラリをいくつか紹介しておきます。

* router.cr  
  最小限のルーティング機能を持つライブラリで、高いパフォーマンスが出ています。

* radix  
  パスの登録と検索をradix treeというデータ構造を用いて高速に行うライブラリです。amber、kemal、raze、router.crといった多くのWebフレームワークの内部で使われています。

* phoenix.cr  
  プログラミング言語ElixirのWebフレームワークであるPhoenixのChannelを実装したライブラリです。topicモデルを採用しており、メッセージをtopicに対して送受信します。

今回はRazeを参考にしてフレームワークを作っていきたいと思います。


## HTTPモジュール
CrystalにはHTTPモジュールがあり、ServerやClient、HandlerなどのHTTP関連のクラスがこの中に入っています。まずはこのHTTPモジュールに触れることで、Handlerとはどういったものかを見ていきたいと思います。

CrystalではHTTP::Serverを使うことで、簡単にHTTPサーバを作ることができます。

```rb
require "http/server"

server = HTTP::Server.new("0.0.0.0", 8080) do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

puts "Listening on http://0.0.0.0:8080"
server.listen
```

```
$ crystal server.cr
Listening on http://0.0.0.0:8080
```

ブラウザなどでlocalhost:8080にアクセスすると Hello world! が表示されます。

```
$ curl -X GET http://localhost:8080
Hello world!
```

HTTP::Handlerを使って見ましょう。下にあるのがHTTP::Handlerの実装です。
Handler（Middleware）はサーバとアプリケーションの外部の間、つまりサーバの前にあり、サーバにリクエストが入る直前とサーバからレスポンスが出てきた直後のタイミングで様々な処理をすることができます。
また、HTTP::Handlerは複数積み重ねることができます。HTTP::Handlerは次のHTTP::Handlerをnextプロパティとして持っていて、call_nextメソッドを呼び出すことで次のHTTP::Handlerのcallを呼び出します。

```rb
# crystal/src/http/server/handler.cr

module HTTP::Handler
  property next : Handler | Proc | Nil

  abstract def call(context : HTTP::Server::Context)

  def call_next(context : HTTP::Server::Context)
    if next_handler = @next
      next_handler.call(context)
    else
      context.response.status_code = 404
      context.response.headers["Content-Type"] = "text/plain"
      context.response.puts "Not Found"
    end
  end

  alias Proc = HTTP::Server::Context ->
end
```

HTTP::Handlerを使うには、自分のクラスにincludeして、callメソッドを実装します。作ったHandlerはHTTP::Serverのコンストラクタに渡すことができます。

```rb
require "http/server"

class TimeLogger
  include HTTP::Handler

  def call(context)
    start = Time.now
    response = call_next(context) # sends request to next handlers
    finish = Time.now
    puts "%.4f ms" % ((finish - start).to_f * 1000)
    response
  end
end

# Handlerをセットできる
server = HTTP::Server.new("0.0.0.0", 8080, [TimeLogger.new]) do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

puts "Listening on http://0.0.0.0:8080"
server.listen
```

先ほどと同じようにアクセスすると、レスポンスが返るまでの時間が出力されます。

```
$ crystal server.cr
Listening on http://0.0.0.0:8080
0.1770 ms
```

HTTP::Serverのコンストラクタをみてみましょう。build_middlewareの中で渡されたHTTP::Handlerの配列のnextプロパティに配列の次のHTTP::Handlerがセットされ、渡したブロックが配列の末尾に追加されます。

```rb
class HTTP::Server
  # ...

  def initialize(@host : String, @port : Int32, handlers : Array(HTTP::Handler), &handler : Context ->)
    handler = HTTP::Server.build_middleware handlers, handler
    @processor = RequestProcessor.new(handler)
  end

  # ...

  def self.build_middleware(handlers, last_handler : (Context ->)? = nil)
    raise ArgumentError.new "You must specify at least one HTTP Handler." if handlers.empty?
    0.upto(handlers.size - 2) { |i| handlers[i].next = handlers[i + 1] }
    handlers.last.next = last_handler if last_handler
    handlers.first
  end
end
```

## Radix
今回はルーティングの部分にradixを使います。Razeを含む多くのCrystalのWebフレームワークはルーティング部分にradixを使用しています。このライブラリは元々はkemalのために作られたライブラリですが、razeやamberといったCrystalのフレームワークの多くで使用されています。

```yml
dependencies:
  radix:
    github: luislavena/radix
```

```sh
icr(0.23.1) > require "radix"
icr(0.23.1) > tree = Radix::Tree(Symbol).new
icr(0.23.1) > result = tree.find "/products/featured"
icr(0.23.1) > puts result.payload
featured
```

このluislavena/radixというライブラリに限って言えば、パスを表すStringをKeyに、HandlerのスタックをValueにもつ連想配列とみることができます。Valueの型は変えることができますが、kemalとamberではHandlerに相当する部分（フレームワーク内ではRouterと呼ばれている）のStackの先頭のHandlerを、RazeではHandlerのStackそのものをValueに持っています。

## フレームワーク実装
今回作るフレームワークはRazeを参考にしたもので、次のような設計です。

![img](https://github.com/TobiasGSmollett/techbookfest3/blob/tobias/img.001.png)

次の順番で実装していきます。
1. Handler
2. Stack
3. ServerHandler
4. Fw
5. DSL

### Handler

callメソッドのシグネチャを定義します。HTTP::Handlerとは少し違いますが、RazeではContextと次のFw::Handlerのcallメソッドを呼び出す為のProcであるdoneを受け取るように実装しています。

```rb
require "http/server"

module Fw
  module Handler
    abstract def call(ctx : HTTP::Server::Context, done : HTTP::Server::Context -> (HTTP::Server::Context | String | Int32 | Int64 | Bool | Nil))
  end
end
```

### Stack

```rb
module Fw
  class RouteNotFound < Exception
    def initialize(ctx)
      super "Requested path: '#{ctx.request.method.to_s}:#{ctx.request.path}' was not found."
    end
  end
end
```

Fw::Handlerを積むためのStackです。このStackはmiddlewaresと言う名前のHandlerを格納する為の配列を持っていて、クラスの外からrunメソッドを呼ぶことでこの配列の先頭のHandlerから順にcallメソッドを呼び出すことができます。

```rb
require "./*"

module Fw
  class Stack    
    def initialize(@middlewares : Array(Handler), &@block : HTTP::Server::Context -> (HTTP::Server::Context | String | Int32 | Int64 | Bool | Nil))
    end

    def run(ctx : HTTP::Server::Context)
      self.next(0, ctx)
    end

    private def next(index : Int32, ctx : HTTP::Server::Context)
      if mw = @middlewares[index]?
        mw.call ctx, ->{ self.next(index + 1, ctx) }
      elsif block = @block
        block.call(ctx)
      else
        raise Fw::RouteNotFound.new(ctx)
      end
    end
  end
end
```

### ServerHandler

ServerHandlerはHTTP::Serverとルーティング用のRadixとミドルウェアのStackを結びつけるクラスで、Radixを持ち、Radixのaddをラップするメソッドadd_stackを定義しています。また、ServerHandlerはHTTP::Serverのインスタンス化時に引数として渡したいので、HTTP::Handlerをincludeしています。

```rb
require "http"
require "./*"
require "radix"

module Fw
  class ServerHandler
    include HTTP::Handler

    INSTANCE = new

    def initialize
      @tree = Radix::Tree(Fw::Stack).new
    end

    def add_stack(method, path, stack)
      lookup_result = @tree.find "/#{method.downcase}#{path}"
      raise "There is already an existing path for #{method.upcase} #{path}." if lookup_result.found?
      @tree.add "/#{method.downcase}#{path}", stack
      @tree.add("/head#{path}", Fw::Stack.new([] of Fw::Handler) { |ctx| "" }) if method == "GET"
    end

    def call(ctx)
      # パスが定義されているかのチェック
      node = "/#{ctx.request.method.downcase}#{ctx.request.path}"
      lookup_result = @tree.find node
      raise Fw::RouteNotFound.new(ctx) unless lookup_result.found?

      # ルーティングにマッチしたスタックの先頭のcallメソッドを呼び出す
      stack = lookup_result.payload.as(Fw::Stack)
      content = stack.run ctx
    ensure
      ctx.response.print content
    end
  end
end
```

### Fw

Fwはこのフレームワークのエンドポイントになります。下のコードを見ての通りですが、hostとportを受け取ってHTTP::Serverをインスタンス化します。この時にHTTP::Handlerをincludeしたクラスを渡すことができます。

```rb
require "./fw/*"

module Fw
  def self.run(host = "0.0.0.0", port = 7777)
    server = HTTP::Server.new(host, port, Fw::ServerHandler::INSTANCE)
    server.listen
  end
end
```

### DSL

最後にDSLを作ります。各メソッドの中ですることは
1. 引数で受け取ったFw::Handlerの配列をFw::Stackにする
2. Fw::ServerHandlerのadd_stackメソッドで、パスとStackを紐づけて登録する
の2つになります。

```rb
require "./*"

HTTP_METHODS_OPTIONS = %w(get post put patch delete options)

{% for method in HTTP_METHODS_OPTIONS %}
  def {{method.id}}(path, &block : HTTP::Server::Context -> (HTTP::Server::Context|String|Int32|Int64|Bool|Nil))
    stack = Fw::Stack.new([] of Fw::Handler, &block)
    Fw::ServerHandler::INSTANCE.add_stack {{method}}.upcase, path, stack
  end

  def {{method.id}}(path, middlewares : Array(Fw::Handler), &block : HTTP::Server::Context -> (HTTP::Server::Context|String|Int32|Int64|Bool|Nil))
    stack = Fw::Stack.new(middlewares, &block)
    Fw::ServerHandler::INSTANCE.add_stack {{method}}.upcase, path, stack
  end
{% end %}
```

## 使い方
実際に作ったフレームワークを使って見ましょう。RazeやKemalと同じように書けます。

```rb
require "./fw"

get "/hello" do |ctx|
  "hello, world!"
end

Fw.run
```


## まとめ
