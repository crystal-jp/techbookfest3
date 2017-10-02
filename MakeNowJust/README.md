# イントロダクション (著者: TSUYUSATO Kitsune[^MakeNowJust-profile])

[^MakeNowJust-profile]: Twitter: @make_now_just

## はじめに

こんにちは。「さっき作った」ことMakeNowJustです。「Crystalの本 その3」を手に取っていただきありがとうございます。

この章ではCrystalがどんな言語なのか、どうやってインストールするのか、などについて簡単に説明していきたいと思います。

そんなことはもう知ってるよ、という方は適当に読み飛ばしていってかまいません。

## 特徴

CrystalはRubyのような構文を持っていて、しかしLLVMを介してコンパイルされるため非常に高速に動作するプログラミング言語です。

例えばFizzBuzzであればこのように書けます。

```crystal
(1..100).each do |i|
  case
  when i % 15 == 0
    puts :FizzBuzz
  when i % 3 == 0
    puts :Fizz
  when i % 5 == 0
    puts :Buzz
  else
    puts i
  end
end
```

ほとんどRubyと同じというか、そのままRubyとして実行できるくらいRubyに近いことが分かると思います。

またC言語で書かれた既存のライブラリとの連携も比較的に簡単に行うことができます。

詳細については https://crystal-lang.org/docs/syntax_and_semantics/ を参照してください。

## インストール方法

macOSであれば、Homebrewを利用して、

```console
$ brew install crystal
```

でインストールできます。

DebianやUbuntuであれば、

```console
$ curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
$ sudo apt install crystal
```

としてインストールできます。

その他のOSでのインストール方法は https://crystal-lang.org/docs/installation/ を参照してください。
