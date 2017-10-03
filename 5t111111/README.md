# Crystal の並行処理 (著者: Hirofumi Wakasugi[^5t111111-profile])

[^5t111111-profile]: Twitter: @5t111111

この章では Crystal の並行処理の概要について書きますが、内容はほぼ、公式ドキュメントの「Concurrency[^Concurrency-URL]」を日本語に翻訳したものとなります。

[^Concurrency-URL]: <https://crystal-lang.org/docs/guides/concurrency.html>

## 並行 (Concurrency) vs 並列 (Parallelism)

まず、並行 (Concurrency) と並列 (Parallelism) という2つの概念、これらの両者は混同されがちですが異なるものです。

やるべき作業がたくさんあるとき、処理を並行して行うことでそれらを効率的にこなすことができます。しかし、並行処理といった場合、必ずしも作業をまったく同時に実行するとは限りません。例えば、何か料理しているところを想像してみてください。きっと、玉ねぎを煮込んでいる間にサラダのトマトを切ったりすることでしょう。これは料理を並行で作っていると言えますが、自分がそれらの作業を全く同時に行っているわけではないですよね。それぞれの作業に対して自分の時間を効率的に割り当てている、と言う方が適切です。これが並行処理です。一方で、並列処理は「片方の手で玉ねぎを切り、同時にもう片方の手でトマトを切る」といった動作に例えることができます。

現時点では、Crystal がサポートするのは並行処理だけです。並列処理はサポートしていません。つまり、複数のタスクを一度に実行することは可能ですが、それらのコードが厳密に同時に実行されることはありません。

Crystal のプログラムは NS の単一スレッド上で実行されます。ただし、ガベージコレクタ (GC) だけは例外で、並行処理によって実行されるマーク・アンド・スイープ方式で実装されています。現在、Crystal の GC の実装には Boehm GC[^Boehm-GC-URL] を採用しています。

[^Boehm-GC-URL]: <http://www.hboehm.info/gc/>

### Fiber

Crystal で並行処理を実現しているものは fiber です。Fiber は OS スレッドに似ていますが、より軽量であり、プロセスの内部で管理されるという点が異なります。したがって、1つのプログラムの中で複数の fiber が生成され、Crystal はそれらが正しいタイミングで実行されるように管理します。

### イベントループ

I/O に関連するものはすべてイベントループを持っているので、時間のかかる処理が移譲された場合は、イベントループがそれらの処理が終わるのを待っている間に他の fiber の実行を継続することが可能になっています。このシンプルな例として、ソケットがデータを待機している状態があげられます。

### Channel

Crystal には CSP[^CSP-URL] に影響を受けた channel というものがあります。これによって、共有メモリを利用することなく、また、ロックやセマフォ、その他特殊な機構を気にすることなく fiber 間でデータのやり取りをすることが可能になっています。

[^CSP-URL]: <https://en.wikipedia.org/wiki/Communicating_sequential_processes>

## プログラムの実行

プログラムを開始したとき、トップレベルのコードを実行するためのメイン fiber が起動されます。そして、それは他のたくさんの fiber を生成することができます。

プログラムの構成を簡単にまとめると以下となります。

* ランタイムスケジューラ: すべての fiber を正しいタイミングで実行するためのもの
* イベントループ: これは単純に別の fiber だが、特にファイル/ソケット/パイプ/シグナル/タイマー (例えば `sleep`) などの非同期のタスクのためのもの
* Channel: Fiber 間でデータをやり取りするためのもの。ランタイムスケジューラによって、fiber と channel が協調して動作する
* ガベージコレクタ: 使われなくなったメモリを掃除する

### Fiber

Fiber とは、スレッドより軽量な実行単位であり、8MB のスタック領域が割り当てられた小さなオブジェクトです。

そして、fiber とスレッドの大きく異なる点は、fiber が「協調して動作」するものだということです。スレッドはプリエンプティブな仕組みであるため、OS はいつでもスレッドを中断し、別のスレッドを実行することが可能です。一方、fiber は明示的にランタイムスケジューラに指示することで他の fiber に切り替わります。例えば、待機状態になる I/O があった場合を考えてみましょう。ある fiber はスケジューラにこのように伝えます。「ねえ、私はこの I/O が使えるようになるまで待たなくちゃいけないから、その間に他の fiber を実行してて。で、I/O の準備ができたらまたこっちに戻してくれない？」

このように協調して動作することの利点は、(スレッド切り替えのための) コンテキストスイッチのオーバーヘッドを大きく減少させることができることです。

また、Fiber はスレッドと比較してかなり軽量です。割り当てられる領域は 8MB ですが、最小では 4KB の小さなスタックとなります。

64bit のマシンでは、何百万、何千万もの fiber を生成することが可能です。一方、32bit のマシンで生成可能な fiber は最大数は 512 であり、決して多くありません。ただ、もはや 32bit のマシンは廃れてきているので、将来を見据えて 64bit にフォーカスした仕様としています。

### ランタイムスケジューラ

スケジューラはキューを持ち、キューには以下が入ります。

* 実行可能状態の fiber: 例えば、fiber を生成したときには実行可能な状態です。
* イベントループ: これは別の fiber で、他に実行可能状態の fiber が存在しない場合に、イベントループは実行可能な非同期処理がないかチェックします。そして、その処理を待機している fiber を実行します。現在、イベントループは `libevent` によって実装されており、それによって `epoll` や `kqueue` といったイベント機構を抽象化しています。
* 自ら待機状態になっている Fiber: `Fiber.yield` によってこの状態になります。ざっくり言うと「自分は実行を続けることができるけど、よかったら別の fiber を実行するための時間をあげるよ」といった状を指します。

### データの通信

現在はコードは単一スレッドで動作するため、異なる fiber から別の fiber のクラス変数にアクセスして更新することも問題なく可能です。しかし、もしマルチスレッド (並行処理) がサポートされたときには上記は破綻してしまいます。したがって、データの通信で推奨する方法は、channel を利用して相互にメッセージをやり取りするというものです。内部的には、データの競合を避けるために channel にはロック機構が実装されています。ただ、外部的には簡単な通信機構として利用できる設計になっており、(ユーザーとしては) ロックを使用する必要はありません。

## サンプルコード

### Fiber の生成

Fiber を生成ためには、ブロックを指定して `spawn` を使います。

```crystal
spawn do
  # ...
  socket.gets
  # ...
end

spawn do
  # ...
  sleep 5.seconds
  # ...
end
```

上記には2つの fiber があります。1つはソケットから読み取るもので、もう1つは `sleep` するものです。最初の fiber が `socket.gets` の行に到達すると、その fiber はサスペンド状態になり、イベントループはソケットにデータが準備できたときに fiber の実行を再開するように指示されます。そして、プログラムは2つ目の fiber を実行します。この fiber は5秒間 sleep するので、イベントループは5秒間この fiber の実行を継続するように指示されます。他に実行すべき fiber がなければ、イベントループは上記のいずれかのイベントが発生するまで待機します。そのとき CPU 時間は消費しません。

`socket.gets` や `sleep` がこのような振る舞いをする理由は、それらが直接対話する相手がランタイムスケジューラーやイベントループである実装になっているからで、それ以上に何か特別なことが行なわれているわけではありません。基本的には、標準ライブラリがこういった処理の面倒を見てくれるようになっているため、自分で操作する必要はありません。

しかしながら、fiber が即座に実行されるのではないことは知っておく必要があります。例をあげます。

```crystal
spawn do
  loop do
    puts "Hello!"
  end
end
```

上記のコードを実行すると、何の出力もないままにプログラムはすぐに終了してしまいます。

これは、fiber が生成されたら即座に実行されるのではないことが理由です。つまり、上記の fiber を生成するメインの fiber が実行を完了すると、その時点でプログラムが終了してしまうということです。

これを解決する方法の1つが `sleep` の利用です。

```crystal
spawn do
  loop do
    puts "Hello!"
  end
end

sleep 1.second
```

このプログラムは1秒間「Hello!」と表示してから終了します。この理由は、`sleep` の呼び出しによってメインの fiber が1秒後に実行されるように設定され、そのときに他の「実行可能状態」の fiber (上記のコードでは "Hello" を出力する fiber になりますね) が実行されるためです。

もう1つの方法は以下です。

```crystal
spawn do
  loop do
    puts "Hello!"
  end
end

Fiber.yield
```

このとき、`Fiber.yield` はスケジューラーに他の fiber を実行するよう指示します。その結果、標準出力がブロックされるまで「Hello!」が出力された状態となり、それからメインの fiber の実行が再開されてプログラムが終了します。この場合は、標準出力がブロックされることはないため、プログラムはずっと実行され続けることになるでしょう。

生成した fiber を永遠に実行し続けたいのであれば、引数なしの `sleep` を利用するこができます。

```crystal
spawn do
  loop do
    puts "Hello!"
  end
end

sleep 1.second
```

もちろん、上記のプログラムを `spawn` を使わない無限ループで書くことも可能ですが、複数の fiber を生成するような状況であれば `sleep` の方がより効果的です。

### メソッド呼び出しを spawn する

ブロックではなく、メソッド呼び出しを渡して spawn することも可能です。以下の例を見ながら、これが役に立つ場面を考えてみましょう。

```crystal
i = 0
while i < 10
  spawn do
    puts(i)
  end
  i += 1
end

Fiber.yield
```

上記のプログラムは、「10」を10回出力します。これは期待した結果でしょうか？おそらく違いますよね。このプログラムの問題は、すべての生成された fiber が `i` という唯一の変数を参照するため、`Fiber.yield` が実行されたときにはその値 は 10 になってしまっています。

この問題を解決するためには以下のようにすればよいです。

```crystal
i = 0
while i < 10
  proc = ->(x : Int32) do
    spawn do
      puts x
    end
  end
  proc.call i
  i += 1
end

Fiber.yield
```

これで期待通りの動作になります。なぜなら、上記では Proc[^Proc-URL] を生成して `i` を渡して実行することにより、fiber は値のコピーを受け取るようになるためです。

[^Proc-URL]: <http://crystal-lang.org/api/Proc.html>

ただ、これを毎回書くのは大変なので、標準ライブラリには `spawn` マクロが用意されており、メソッド呼び出しの式を受け取って上記のような書き換えを行うことができます。それを使うと以下のように書けます。

```crystal
i = 0
while i < 10
  spawn puts(i)
  i += 1
end

Fiber.yield
```

イテレーションごとに変化するローカル変数を扱う際にこのマクロは特に有効でしょう。ちなみに、ブロック引数ではこのような挙動にはなりません。例えば、以下は期待通りに動作します。

```crystal
10.times do |i|
  spawn do
    puts i
  end
end

Fiber.yield
```

### 生成した fiber が完了するのを待つ

生成した fiber の実行の完了を待つには channel を利用します。

```crystal
channel = Channel(Nil).new

spawn do
  puts "Before send"
  channel.send(nil)
  puts "After send"
end

puts "Before receive"
channel.receive
puts "After receive"
```

この出力は以下となります。

```text
Before receive
Before send
After receive
```

説明すると、まず、プログラムは fiber を生成しますが、その時点では実行しません。そして、`channel.receive` が実行されたとき、メインの fiber がブロックされ、生成された fiber に処理が移ります。それから、`channel.send(nil)` が実行され、これによって値を待っていた `channel.receive` から処理が再開されます。そして、メインの fiber の実行が継続され完了すると、プログラム自体も終了するため、生成された fiber が「After send」を出力する機会なく終了します。

上記の例では、ただ fiber の完了を通知するためだけなので `nil` を利用しましたが、fiber 間で値をやり取りするためにも channel を利用できます。

```crystal
channel = Channel(Int32).new

spawn do
  puts "Before first send"
  channel.send(1)
  puts "Before second send"
  channel.send(2)
end

puts "Before first receive"
value = channel.receive
puts value # => 1

puts "Before second receive"
value = channel.receive
puts value # => 2
```

この出力は以下になります。

```text
Before first receive
Before first send
1
Before second receive
Before second send
2
```

プログラムが `receive` を実行するとき、その fiber はブロックされ、他の fiber に実行が移ります。`send` が実行されたときは、その channel で待機している fiber に処理が移ります。

ここではリテラルの値を送信していますが、生成された fiber は、例えばファイルからの読み込みやソケットからの取得による値を処理することも可能です。この fiber が I/O を待っているとしましょう。そのとき、他の fiber は I/O の準備が完了するまで実行し続け、その値の準備が完了し channel を通して送られたときにはじめてメインの fiber がそれを受け取ります。例をあげます。

```crystal
require "socket"

channel = Channel(String).new

spawn do
  server = TCPServer.new("0.0.0.0", 8080)
  socket = server.accept
  while line = socket.gets
    channel.send(line)
  end
end

spawn do
  while line = gets
    channel.send(line)
  end
end

3.times do
  puts channel.receive
end
```

上記のプログラムでは2つの fiber が生成されます。1つ目の fiber では `TCPServer` を用意し、受け入れたコネクションから行を読み込んで、それを channel に送信しています。そして、2つ目の fiber は標準入力から行を読み取ります。メインの fiber は、ソケット、もしくは標準入力から channel に送信された最初の3つのメッセージを読み取り。その後でプログラムが終了します。`gets` の呼び出しは fiber の実行をブロックし、データが入力されたらそこから開始するようにイベントループに指示します。

同様に、複数の fiber が実行を完了し値を取得するのを待つことも可能です。

```crystal
channel = Channel(Int32).new

10.times do |i|
  spawn do
    channel.send(i * 2)
  end
end

sum = 0
10.times do
  sum += channel.receive
end
puts sum # => 90
```

もちろん、生成した fiber の内部で `receive` を使うことも可能です。

```crystal
channel = Channel(Int32).new

spawn do
  puts "Before send"
  channel.send(1)
  puts "After send"
end

spawn do
  puts "Before receive"
  puts channel.receive
  puts "After receive"
end

puts "Before yield"
Fiber.yield
puts "After yield"
```

出力は以下になります。

```text
Before yield
Before send
Before receive
1
After receive
After send
After yield
```

このとき、 `channel.send` がまず最初に実行されますが、その時点では (まだ) 値を待っている fiber がありません。次に2つ目の fiber が実行されますが、そのとき channel には値が存在する状態なので、その値が取得されて処理が実行されます。`Fiber.yield` は fiber を実行キューの最後に設定するので、その後はまず1つ目の fiber が実行され、その後でメインの fiber が実行されます。

### Buffered channel

ここまでの例では unbuffered (バッファリングされない) channel を使っています。つまり、値を送信するとき、その channel で待機中の fiber があればその時点でその fiber に処理が移ります。

一方、buffered (バッファリングされる) channel を使うと、バッファがフルにならない限り、`send` は別の fiber に処理を切り替えません。

```crystal
# キャパシティ 2 の buffered channel
channel = Channel(Int32).new(2)

spawn do
  puts "Before send 1"
  channel.send(1)
  puts "Before send 2"
  channel.send(2)
  puts "Before send 3"
  channel.send(3)
  puts "After send"
end

3.times do |i|
  puts channel.receive
end
```

出力は以下になります。

```text
Before send 1
Before send 2
Before send 3
1
2
After send
3
```

最初の2度の send では別の fiber に処理が切り替わっていないことに注目してください。3つ目の send でバッファがフルになっている channel に送信されたときにはじめて、メインの fiber に処理が移っています。ここで2つの値を受け取って channel の中身は空になります。そして、3回目の `receive` でメインの fiber の処理がブロックされて別の fiber に処理が移り、そこで別の値の送信を行います。


