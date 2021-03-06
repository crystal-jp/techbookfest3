# Crystal ならではの小ネタ (著者: Tomokazu Imamura[^pacuum-profile])

[^pacuum-profile]: Twitter: @pacuum

## はじめに
はじめまして。@pacuumと申します。普段はベトナムのハノイでベトナム国内向けプロダクトの開発をしています。最近はあまりコードは書かなくなったのですが、自分のプロダクトマネージャーとしての職権を乱用して crystal をリコメンドエンジンの実装などに実践投入したりしています。とはいうもののまだCrystalの経験は多くありません。

私が Crystal を使うようになったのはRuby的シンタックス、高速、静的型などの理由もあるのですが、一番の理由はCrystal の型チェックやマクロが他の言語ではあまり見られないユニークな特徴を持っていると感じたからです。この記事ではそのような特徴を使ってできそうなことを幾つか小ネタとしてお話しようと思います。

## 1. クラスのサブセット
私は長い間 Rails で開発をしてきました。Rails はとても素晴らしいフレームワークなのですが、長期間使い続けると色々な問題に悩まされるようになりました。最も顕著な問題はパフォーマンス、特に ActiveRecord のパフィーマンスです。複雑な処理をしようとして多数のレコードや関連データを取得するといとも簡単に大量のメモリを消費して処理が非常に遅くなってしまいます。これを回避するために「不要なフィールドを取得しないことで高速化する」というテクニックがしばしば用いられます。

このような「あるモデルのフィールドのサブセットからなるモデル」を作りたいという状況を考えます。フィールドは制限するものの、元のクラスで定義されているメソッドは出来る限り再利用したいものとします。これは ActiveRecord に限らず大量のデータを扱う際には一般的に起こりうる要求かと思います。

例として以下のようなモデルを考えます。`User` は `email`, `user_type_id`, `created_at` の３つのフィールドを持つとします。

```ruby
class User < ActiveRecord::Base
  def gmail?
    @email =~ /gmail.com/
  end
  
  def recent_user?
    @created_at >= 1.week.ago
  end
  
  def free_user?
    recent_user? ||
      @user_type_id == UserType::FREE_USER
  end
end
```

この `User` モデルに対して `email`, `created_at` のサブセットからなるモデルがほしいとしましょう。ActiveRecordの場合、このようなモデルは `select()` によって簡単に実現できます。

```
subset_users = User.select( :email, :created_at ).all
```

これは実際にはクラスとしては `User` のままでただ単に保持しているフィールドの種類が少ないというだけのものです。したがって `User` クラスに定義されているメソッドは全て呼び出すことができてしまいます。`gmail?` と `recent_user?` については中で使用されているフィールドが `select()` に含まれているので正しい結果を返します。一方で `free_user?` を呼び出した場合 `user_type_id` が定義されていないため実行時例外が出てしまいます。このように、フィールドのサブセットごとに呼び出し可能なメソッドのサブセットが決まるという状況が発生するのですが、どのメソッドなら呼び出しても安全なのかがすぐにわからないのが非常に厄介な問題であり、これを多用するとバグの袋小路に嵌っていくことは明らかです。フィールドのサブセットごとに必要に応じてサブクラスを定義することも考えましたが、フィールドのサブセットによって実行可能なメソッドのサブセットの判定は人間がやるには難しすぎるため、メンテナンスのことを考えるととても管理できないと思い断念しました。

類似の状況として、`User` データをCSVファイルなどから一括登録したいがその時点では `user_type_id` が決まっていないというような、運用フェーズのメンテナンスで起こり得る状況について考えます。このような場合にとりあえず `user_type_id` に `nil` を代入しておいて処理を進めることはできますが、その処理の過程で誤って `free_user?` が呼ばれてしまった場合に嘘の結果を返してしまって危険なので避けたいところです。

想像上の問題を書いているだけで辛くなってくるのですが、この問題、Crystal なら解決することができます。

### Crystal のコンパイル時の挙動

解決策を説明する前に、Crystal コンパイラの挙動について一つ説明をします。Crystal のコンパイラには「呼び出されることが無いとわかっているコードはコンパイルしない」というユニークな特徴があります。Crystal 作者の @asterite さんによると、

> Ruby と同じ挙動をできるだけ保ちたいから

という理由だそうです。どういうことかというと、例えば以下のようなコードを Ruby で実行してもエラーにはなりません。

```ruby
class Test
  def a
    b.new
  end
end
```

`Test#a` から存在しない `b` という参照を用いていますが、`Test#a` 自体が一度も呼び出されることがないためエラーは起こりません。ですが、もしこのクラス定義の次の行に

```ruby
Test.new.a
```

という行を足して Ruby で実行すると即座に実行時エラーが出るようになります。このように Ruby では不完全なコードを書いても実行されない限りはエラーになりません。Crystal もできる限りこの挙動を保つようになっており、呼び出されないことが確実なメソッドはコンパイル対象から除外されます。そのため存在しないフィールドを参照していてもそのコードが使用されないのであればコンパイルエラーになりません。しかしひとたびメソッドが呼び出された瞬間にコンパイルエラーが発生するようになります。

最初にこの挙動を聞いた時は面白いな、程度の感想だったのですが、しばらくコードを書くうちにこれは動的言語のストレスの少なさを静的言語に持ち込むための重要な判断なのではないかと気づきました。Ruby のような動的言語では不完全なコードでも実行することができ、それによってコードを動かしながら少しずつ実装していくというストレスの少ないスタイルの開発が可能となっています。実行時エラーはその代償として課されるものです。一方で一般的な静的言語では実行時エラーを最小限にする代わりにコードの整合性が厳密にチェックされます。全ての整合性が満たされて初めて実行できるため不完全なコードを実行することは（例えそのコードが使われないコードであっても）できません。その為「今書いているコードの書き方これであってるんだっけ？」という疑問が生じた時にとりあえず動かしてみる、ということがしづらく不便を感じます。Crystal はこの中間をうまくとっていて、実行時エラーをなくしつつストレスを減らすような作りになっています。

私は技術のパラダイムの変遷においては常にバブルが起きるというか、一旦行き過ぎて揺り戻しが起こりながら最適なところを目指していくように感じています。２０年ほど前は C や Java のような静的で堅い言語が主流でしたがその後 Ruby や Python のような動的で柔らかい言語が硬い言語への反発として使われるようになりました。その後動的言語の辛さが広く認識されるようになり、型推論やNull安全性などを活用した、静的だけど硬すぎない言語が次々と現れて静的言語への揺り戻しが起こっています。ですが個人的にはダックタイピングに慣れた身にはこの新しい言語はやや硬すぎると感じていました。そこで出てきたのがCrystalです。正直初めて Crystal のことを知ったときは「Ruby のシンタックスを真似たイロモノ言語」という印象だったのですが仕様を調べるうちにそのような認識は全くの誤りで、これはさらにもう一度揺り戻しが起きた先の次次世代言語ではないか？と認識を改めるようになりました。私はあまり沢山の言語を知っているわけではないので見当違いのことを言っているかもしれません。閑話休題。

### Proof of Concept
さて、この Crystal の特徴があれば冒頭のようなサブセット問題を解決することができます。まずはモデルの全てのメソッドを独立した `module` として定義します。`User::Functions` モジュールにはメソッドのみが定義されており、どのようなフィールドを持つかという情報は含まれていません。


```ruby
class User
  module Functions
    def gmail?
      @email =~ /gmail.com/
    end

    def recent_user?
      @created_at >= 1.week.ago
    end
  
    def free_user?
      recent_user? ||
        @user_type_id == UserType::FREE_USER
    end
  end
  include Functions
end
```

そして、`email`, `created_at` のサブセットからなるモデルを以下のように定義します。

```ruby
class SubsetOfUser 
  def initialize(@email : String, @created_at : Time )
  end
  include User::Functions
end
```

`User::Functions` モジュールを単純にインクルードしているのでこのクラスには `free_user?` というメソッドも定義されています。ですがこのメソッドの中で定義されている `user_type_id` は定義されていません。

もし `free_user?` がどこからも呼ばれなかった場合、上記の挙動から `free_user?` はコンパイル対象外となるため `user_type_id` が定義されている必要はなく、上記コードはコンパイルに通ります。
一方でもし `free_user?` がどこかから呼び出された場合はコンパイル対象となり、`user_type_id` が定義されていないというコンパイルエラーが起こります。この場合 `SubsetOfUser` にフィールドを足すなり新しいサブセットモデルを作るなりすれば良いです。

したがって、以上のようにフィールドのサブセットさえ定義すれば正しいメソッドのサブセットが何かは全く気にせずにコーディングができ、実行時例外も起こりません。

## 2. リテラルの値チェック
次はリテラルの値チェックについて話をします。静的型付き言語を使うことでコンパイル時に様々な不整合を検出することができますが、文字列やJSONの中までは型チェックが及ばないため実行時例外は依然起こりえます。例えばURLを含んでいるはずの文字列に誤った形式のURLを書いてしまった場合などです。ユーザからの入力文字列は単にバリデートしてユーザに再入力を促せばよいのですが、コードの中に書かれているリテラルが誤ったフォーマットで記述されていた場合は実行時例外を起こすしかありません。値のバリエーションが数えるほどしか無いのであれば `enum` でコンパイル時チェックできるのですが、値のバリエーションが多い場合はこれも使えません。

このようなものも Crystal なら防ぐことができます。

### やりたいこと
ここでは例として「あるパターンにマッチする文字列」を表す型を作ってみましょう。例えば、URLのフォーマットを持つ文字列のみを保持されていることが保証されている型などです。

より具体的には以下のような性質を満たす型をつくります。
- 正しいフォーマットの文字列リテラルが渡された場合は非 `Nil` な `URL` インスタンスを返す。
- 誤ったフォーマットの文字列リテラルが渡された場合はコンパイルエラーを返す。
- 変数などリテラルではないものが渡された場合はコンパイル時のチェックは不可能なので実行時にチェックを行う。そのため戻り値の型は `URL | Nil` のユニオン型となる。

これはコードで書くと以下のように表現できます。

```rb
URL.parse("http://www.google.com") #=> URL

URL.parse("abc123") #=> compile error "Invalid URL"

s = "http://www.google.com"
URL.parse(s) #=> URL|Nil
```

### コード
マクロを使えばこの実装は難しくはありません。文字列リテラルが渡された場合に限りマクロの中で文字列が正規表現にマッチするかどうかコンパイル時にチェックして、もしマッチしなければコンパイルエラーを起こすだけです。もし文字列リテラルが渡されなかった場合は実行時にチェックを行います。

```rb
class URL
  REGEX = /http(s)?:/
  def initialize(url)
    raise "invalid pattern" unless url =~ REGEX
    @url = url
  end

  macro parse(str)
    {% if str.is_a? StringLiteral %}
      {% if str =~ REGEX %}
        URL.new({{str}})
      {% else %}
        {% raise "invalid URL pattern" %}
      {% end %}
    {% else %}
      ({{str}} =~ URL::REGEX ? URL.new({{str}}) : nil)
    {% end %}
  end
end
```

実際コンパイルエラーを出してみると以下のようになります。

```
Error in url.cr:25: invalid URL pattern

url = URL.parse("abc123")
          ^~~~~
```

この考え方は長さの制限された文字列リテラルやIPアドレス、地図上の座標など、色々なバリエーションに応用できる有用なテクニックではないかと思います。ただし現状正規表現やシンプルな Crystal コードでできる以上のことをチェックするのは大変だと思います(JSONなど)。

このようなことが簡単にできるのも Crystal 自身が Crystal で記述されており、macro の中で(制限があるものの) Crystal が使えることが大きいと思います。上記クラスの中に `REGEX` という正規表現の定数が定義されていますが、これを実行時だけではなく、コンパイル時のマクロの中でも使うことができていることに注意してください。

## 3. ID 型を作る
最後のトピックはID型についてです。私は Rails アプリをよく開発していますが、その中でモデルの ID をキーにした `Hash` を作ってルックアップテーブルを作るということがよくあります。例えば `user_id` から `User` オブジェクトへのマップを作るなどです。そうした時に時々やってしまう間違いとして、 `user_id` をキーに持つマップに対して別のモデルのID、例えば `item_id` などを渡してルックアップしてしまうことがあります。どちらも通常 `Int` として実装されるため、型チェックがあったとしてもこの間違いは起きてしまいます。Crystal には `alias` があり型の別名をつけることができるのでこれでいけるのではと思いましたがこれは本当にただの別名であり、名前が別でも同じものとして認識されてしまいますのでこの種の間違いを防ぐためには役に立ちません。

一つの解決法はJavaの `Integer` 型のように別のクラスでボクシングしてしまうことです。例えば `UserId` という ID値のみを持つクラスを作ることで異なるモデルのIDを比較するような間違いを防ぐことができます。しかしながらボクシングはオーバーヘッドを伴います。Crystal の場合 `UserId` クラスでラップすると `Int32` をそのまま扱った場合よりも３倍ほど多くメモリを消費します。これは通常のウェブアプリのような用途では大した問題にはなりませんが、リコメンドエンジンなど数値を多数取り扱う場面では大きな違いを生みます。オーバーヘッド無しに型安全にできる方法は無いのでしょうか？

幸いにも Crystal には `struct` があります。これはC言語の struct に近いもので以下のように定義することができます。

```ruby
struct UserId
  def initialize(@value : Int32)
  end
end
```
この `struct` は `@value` という `Int32` フィールド一つのみを持つデータ構造です。`struct` が `class` と違う点は

* コンパクトに表現される。`Int32` しか持たない `struct` は `Int32` と同じサイズしか必要としない。クラスにした場合はさらにクラスIDを格納する 4byte が余分に消費される。
* 参照渡しではなく値渡しとして扱われる。したがって配列などを作った場合も配列には参照ではなく値が格納される（と思われるメモリ消費パターンを示す）ためさらにデータを節約できる。
* 値として扱うことを想定しているので `==` などは最初から定義されている。

まさに求めていたものです。同様に `ItemId` を定義して試してみると、以下のように `UserId` の配列に `ItemId` を誤って追加してしまうことはありません。

```ruby
user_ids = [] of UserId
user_ids.push ItemId.new(1) #=> no overload matches 'Array(UserId)#push' with type ItemId
``` 

また等値判定は以下のように動作します。

```ruby
p UserId.new(123) == UserId.new(123) #=> true
p UserId.new(123) == ItemId.new(123) #=> false
p UserId.new(123) == 123 #=> false
```

本当は最初のケース以外はコンパイルエラーになって欲しいのところなのですがそこは今後の課題とします。

## まとめ
ということでCrystalならでは、と思われる使い方を幾つか紹介させてもらいました。アイデアレベルのものにすぎないので実際に実用するにはハードルがあるかもしれません。

上で述べたようにCrystalは単に速くて安全なRubyという以上にユニークな特徴を備えています。今後も注目していきたいと思います。

