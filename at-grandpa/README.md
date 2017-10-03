# Crystalのエディタサポート状況まとめ (著者: Yoshiyuki Tsuchida[^at_grandpa-profile])

[^at_grandpa-profile]: Twitter: @at_grandpa

## はじめに

こんにちは。 @at_grandpa と申します。第２回技術書典に引き続き、今回も参加させていただきます。

### エディタによってその言語が好きになる？

早速ですが、みなさん、普段の開発にはどのエディタを使用していますか？この質問自体が宗教論争を生みそうですが、エンジニアにとって重要なツールであるエディタは、日々の生産性を左右する重要な部分でもあります。（恐れずに言いますと）以前私はVimを使っていましたが、最近は Visual Studio Code に移行しました。とはいえまだ、他にも使用したことのないエディタもあるので、今後機会があれば触ってみたいと考えています。

エディタの設定はどのようにしているでしょうか。私がVimから移行した理由の一つに、「設定が複雑になりすぎて管理しづらくなった」というものがあります。`.vimrc`がどんどん肥大化し、どこに何の設定が書かれているかがわかりにくく、次第にVimの応答速度も遅くなっていきました（私の管理の問題もあります）。普段はPHPとRubyを書いているのですが、あるときGoを触る機会があり、その際のVimの設定をしていたのですがどうも煩雑です。そこで思い切って「別のエディタに乗り換えてみよう」と思い、Visual Studio Code を触ってみました。Goの拡張機能を探しサクッとinstallしました。それだけの設定で、自分の思ったとおりのコーディングができるようになりました。自動フォーマット、充実したスニペット、リアルタイムなエラー検知、定義位置へのジャンプ、デバッグ、などなど。しっくりくるサポートで、どんどんGoを書くことができました。このときふと思い返してみると、「エディタの設定を変えることで、その言語が好きになっていく」と感じたのです。私はいつの間にかGoが好きになっていました。明らかにこれはエディタ設定のおかげです。「言語そのものを好きになるべき」とのご意見もあるかもしれませんが、私は「書いていて楽しい言語が好き」なので、それにはエディタの影響も大きいなと感じたのでした。みなさんもこういう経験はありませんでしょうか。

今回はCrystalの本ということで「Crystalのエディタサポート状況」について書かせていただきます。私の場合、Crystalはエディタの恩恵を受けずとも好きになった言語ですが、今後Crystalを触る方々に「Crystalって書きにくいな」と思われることがないよう、エディタ周りの情報をご提供できればと思います。

さて、（恐れ多いのですが）今回は勝手に、下記のエディタに限定させていただきました。時間の都合上、他のエディタは難しかったので、追ってブログなどで発信できればと思います。

* Vim
* Emacs
* Atom
* Visual Studio Code

これらについて、以下の項目を見ていきます。

* シンタックスハイライト
* 自動インデント
* スニペット
* 自動フォーマット
* エラー検知
* 定義ジャンプ
* Spec実行
* Macro expand
* デバッグ

これらが揃えばCrystalの開発はスムーズに行えるのではないでしょうか。各項目では、以下の記述で対応/未対応を表します。

|記号|説明|
|:---:|---|
|◯|簡単にエディタ対応可能|
|△|対応させるには多少設定が必要|
|✕|対応させるには労力が必要|

では早速見ていきましょう。なお、個人で調べた程度の知識ですので、「こんなサポートもあるよ」などのご意見がある場合は、 @at_grandpa まで教えていただけますと幸いです。

## Vim

言わずと知れたエディタです。最近は私の周りでもIDE勢が多くなってきたものの、Vimを使っている方もまだまだ多くいらっしゃいます。VimのCrystalサポートは [rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)が使いやすかったです。このプラグインを基本とし、デバッグやスニペットなどに必要なプラグインを追加すれば、ほぼ完璧なCrystal環境を構築することができます。さすがvimですね。（プラグイン紹介は一例です。最近だといろいろvim周りも変わってきていて古い情報かもしれません。ご容赦ください。）

|項目|対応|備考|プラグイン|
|---|:---:|---|---|
|シンタックスハイライト|◯||[rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)|
|自動インデント|◯|改行時にインデント|[rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)|
|スニペット|△|neosnippetなどで独自実装が必要|[Shougo/neosnippet.vim](https://github.com/Shougo/neosnippet.vim) など|
|自動フォーマット|◯|保存時にformatterをかけられる|[rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)|
|エラー検知|◯||[vim-syntastic/syntastic](https://github.com/vim-syntastic/syntastic)|
|定義ジャンプ|◯||[rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)|
|Spec実行|◯||[rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)|
|Macro expand|△|vimscriptの記述が必要||
|デバッグ|△|vimgdbというものがあるが情報が古め||

以下、いくつかピックアップして説明します。

### Spec周りが便利

今回の取り組みでいろいろエディタを触りましたが、Vimのspec周りの操作が非常に便利でした。[rhysd/vim-crystal](https://github.com/rhysd/vim-crystal)は、コマンドひとつでspecファイルに飛ぶことができたり、「全spec実行」「カーソル位置のspecを実行」が簡単に行なえます。テストを書きつつ、小規模な修正を繰り返し行なっていくスタイルの方は良いのではないでしょうか。操作感も良かったです。

### `crystal expand`に対応できる

さすがvimです。viscriptを書けば、カーソル上のmacro展開を確認できる`crystal expand`にも対応できます。下記を`.vimrc`に記述すれば、カーソル上のmacro展開を確認できます。

```vim
command! -buffer -nargs=0 CrystalExpand echo s:crystal_expand(expand('%'), getpos('.'))

function! s:crystal_expand(file, pos)
  echo getcwd()
  let l:cmd = printf('crystal tool expand --no-color -c %s:%d:%d %s', a:file, a:pos[1], a:pos[2], a:file)
  return system(l:cmd)
endfunction

NeoBundle 'dbakker/vim-projectroot'
nnoremap ce :ProjectRootExe CrystalExpand<Return>
```

[dbakker/vim-projectroot](https://github.com/dbakker/vim-projectroot)を使用していますので、そちらもインストールしてください。これでmacro上にカーソルを持っていき`ce`とタイプすると、macro展開後のコードを確認することができます。

![](at-grandpa/img/crystal-expand.png)
画像１：crystal expand

## Emacs

こちらも言わずと知れたエディタですね。Vimと双璧をなすエディタとして知られています。公式でも紹介されているのは、[dotmilk/emacs-crystal-mode](https://github.com/dotmilk/emacs-crystal-mode)です。

|項目|対応|備考|プラグイン|
|---|:---:|---|---|
|シンタックスハイライト|◯||[dotmilk/emacs-crystal-mode](https://github.com/dotmilk/emacs-crystal-mode)|
|自動インデント|◯|改行時にインデント|[dotmilk/emacs-crystal-mode](https://github.com/dotmilk/emacs-crystal-mode)|
|スニペット|△|yasnippetなどで独自実装が必要|[joaotavora/yasnippet](https://github.com/joaotavora/yasnippet)|
|自動フォーマット|◯|`M-x crystal-format`でバッファ上をフォーマットできる|[dotmilk/emacs-crystal-mode](https://github.com/dotmilk/emacs-crystal-mode)|
|エラー検知|◯||[flycheck/flycheck](https://github.com/flycheck/flycheck)|
|定義ジャンプ|△|TAGSファイルを生成する。[SuperPaintman/crystal-ctags](https://github.com/SuperPaintman/crystal-ctags)などがある||
|Spec実行|△|elispでシェル実行できるので、specを叩く||
|Macro expand|△|elispでシェル実行できるので、expandを叩く||
|デバッグ|◯|`M-x gdb`でemacs内からgdbを直接呼べる||

### emacs-crystal-mode

普段Emacsを触っていないので、今回の機会に調べてみたのですが、必要な機能は揃っていて十分サポートしてくれるプラグインです。key-mappingを指定すれば、ガシガシ書いてformatして、syntaxチェックして、、、を繰り返せると思います。ただ、定義ジャンプが`tags`頼りになってしまうので、多少設定のハードルは上がります。また、spec実行やexpandもサポートされていないので、elispが書けないとそれらの機能の実現は難しいかもしれません。

### `M-x gdb`

Emacsはデフォルトで`gdb`の呼び出しがサポートされていました。`M-x gdb`の後にバイナリの指定すれば、Emacsのウィンドウ内でgdbを触ることができます。簡単にデバッグしたい方は有用だと思います。


## Atom

GitHub製エディタです。周りでの使用者も増えてきたように思います。人気のエディタなので有志によってCrystalのライブラリも作成されています。しかし、まだ製作中のものであったり、機能が不十分だったりします。例えば、[ide-crystal](https://atom.io/packages/ide-crystal)は、将来実装される予定も含め、機能としては一番充実していますが、現在は修正中であり、実際にダウンロードしても十分に使えません（2017/10/03現在）。これらの現状も含め、今回は「現在のAtomでできるCrystal環境」について書いていきます。


|項目|対応|備考|プラグイン|
|---|:---:|---|---|
|シンタックスハイライト|◯||[language-crystal-actual](https://atom.io/packages/language-crystal-actual)|
|自動インデント|◯||[language-crystal-actual](https://atom.io/packages/language-crystal-actual)|
|スニペット|◯||[language-crystal-actual](https://atom.io/packages/language-crystal-actual)|
|自動フォーマット|✕|（[ide-crystal](https://atom.io/packages/ide-crystal)で実装予定）||
|エラー検知|✕|（[ide-crystal](https://atom.io/packages/ide-crystal)で実装予定）||
|定義ジャンプ|✕|（[ide-crystal](https://atom.io/packages/ide-crystal)で実装予定）||
|Spec実行|✕|（[ide-crystal](https://atom.io/packages/ide-crystal)で実装予定）||
|Macro expand|✕|||
|デバッグ|◯||[dbg-gdb](https://atom.io/packages/dbg-gdb)など|

### `ide-crystal`に期待

冒頭でも述べましたが、[ide-crystal](https://atom.io/packages/ide-crystal)は現在開発中です。このパッケージは[crystal-lang-tools](https://github.com/crystal-lang-tools)という公式のOrganizerが開発を進めています。公式READMEを見ても機能的には充実しており、今後の公開が期待されています。

[ide-crystal](https://atom.io/packages/ide-crystal)が使えない現在、どのパッケージが有用かというと[language-crystal-actual](https://atom.io/packages/language-crystal-actual)となります。こちらはシンタックスハイライトとスニペットのパッケージであるため、フォーマッターや定義ジャンプなどの機能は搭載されていません。

デバッグに関してはgdbのプラグインがあるため（[dbg-gdb](https://atom.io/packages/dbg-gdb)など）、そちらを活用すればGUIでデバッグができるでしょう。ただ、後述しますが、gdbは Mac OS X Sierra ではうまく動作しないので注意が必要です。

## Visual Studio Code

IDEの中では機能が充実している方だと思います。実際に自分はVSCodeを使用していますが、設定も簡単で機能も十分だと思います。検索すると複数のプラグインが出てきますが、現在最も開発が盛んなプラグインは[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)です。このパッケージもCrystal公式の[crystal-lang-tools](https://github.com/crystal-lang-tools)によって開発されています。当初は個人開発プロジェクトだったのですが昇格した形です。


|項目|対応|備考|プラグイン|
|---|:---:|---|---|
|シンタックスハイライト|◯||[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)|
|自動インデント|◯||[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)|
|スニペット|◯||[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)|
|自動フォーマット|◯|コマンド実行で可能|[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)|
|エラー検知|◯||[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)|
|定義ジャンプ|◯||[crystal-lang-tools/vscode-crystal-lang](https://github.com/crystal-lang-tools/vscode-crystal-lang)|
|Spec実行|✕|||
|Macro expand|✕|||
|デバッグ|◯||[WebFreak001/code-debug](https://github.com/WebFreak001/code-debug)など|

### 簡単にinstallできて基本機能が充実している

私が今一番使っているのはVSCodeです。使い勝手としては現状一番良いと思います。VSCodeをインストールしたあとに、VSCode上でCrystalのプラグインを探し、上記のプラグインをインストールするだけです。それだけで、シンタックスハイライト、インデント、スニペット、フォーマッター、エラー検知、定義ジャンプの機能が得られます。サクサクとCrystalのコードが書けますし、気になったら定義へジャンプできます。Crystalのライブラリをshardsでinstallしたときなど、ライブラリの定義を読みに行く手間が圧倒的に減ります。

ただ、spec周りのサポートが欲しいところです。Vimの項目でも書きましたが、全体specの実行とカーソル上のspec実行が欲しいところです。現状だと、VSCode上でシェルを開き、そこで`crystal spec`を実行しています。あと、`crystal expand`もあるともっと充実するでしょう。私は、ライブラリを書いている時はmacroを多用するのですが、その時はとても重宝していました。Vim時代は良かったのですが、現状のVSCodeだとなかなか厳しいので、自分で Pull Request を出してみようと考えています。

## デバッグについて

以上で、各エディタの現状の説明を終わります。ここではcrystalのデバッグについてお話します。Crystalのデバッグには`lldb`や`gdb`を使うのが一般的かと思います。しかし、まだCrystal側のでのサポートが十分ではなく、オブジェクトの詳細までは細かく確認することが難しいようです。簡単なプログラムなら可能ですが、複雑化してくると、いくつかの引数の表示がされなかったりします。

また、`gdb`が`Mac OX X Sierra`に完全に対応しているようではなく、`Sierra`でのgdbを使用したデバッグでは、変数の情報を取得できませんでした。`El Capitan`の場合はgdbで変数情報を取得できることは確認しました。`Sierra`でCrystalのデバッグを行うには、VirtualBoxでUbuntuを入れるなどの対応が必要そうです。

![](at-grandpa/img/debug-ubuntu.png)
画像２：Ubuntuでのデバッグの様子

## さいごに

駆け足で「Crystalのエディタサポート状況まとめ」について書きましたが、いかがでしたでしょうか。使用したことのないエディタについて調べることは、なかなか大変な部分もありましたが、逆にそれは「今からCrystalを触ろうとする人」の気持ちになって調べられたのかなと思います。

エディタは「その言語を好きになるか」にとって重要なファクターだと考えています。これから広まっていこうとする言語にとっては特に重要でしょう。インストールが簡単で機能が充実していることが大切です。私もCrystalプラグインには恩恵をいただいているので、「もうちょっとこの機能がほしいな」と思う部分については Pull Request を出していこうと思います。好きな言語への貢献は、こういった方法もあるのだと気付かされました。

ぜひみなさんも、自分の好きなエディタでCrystalを好きなだけ書けるように設定してみてください。
