Title: CrystalとWeb 2
Author: msky
Twitter: @msky026

# はじめに

1年前の技術書典1で「CrystalとWeb」について記述しました。  
そこでKemalを用いて簡単なCRUD機能を持つミニブログを作成しました。
作成物については[kemal-sample](https://github.com/msky026/kemal-sample)を参照してみてください。  
それからCrystalやKemalも多くの点で変更になりました。  
本稿では前回作成した箇所からの変更点のうち以下の内容について解説します。

- DBの扱い方について
- セッションについて

## DB接続設定の変更

まず主だった変更点として、DB接続を行うモジュールが変更されました。  
以前はPostgreSQLを使用する際はkemal-pgを使ってDBに接続していましたが、DB接続関連は[crystal-db](https://github.com/crystal-lang/crystal-db)のライブラリがデファクトスタンダードになっています。こちらのライブラリは現時点でコネクションプールも備えております。  
以前はコネクションプール使用時には専用のライブラリを使用していましたがそれも不要になりました。  

以下に変更点について記載していきます。変更点のみの記述となりますが、全体像が見たい方は、上記でも記載していますが、[kemal-sample](https://github.com/msky026/kemal-sample)を参照してみてください。  
また、本サンプルは全てCrystal ver 0.23.0で実行しております。  

`shard.yml`ファイルを以下の内容に修正します。  

```
name: kemal-sample
version: 0.2.0

dependencies:
  kemal:
    github: sdogruyol/kemal
    branch: master

dependencies:
  db:
    github: crystal-lang/crystal-db
    branch: master
```

修正後に以下のコマンドを実行します。

```
shards update
```

続いてソースの修正を行っていきます。

`src/kemal-sample.cr`
```crystal
require "kemal"
require "db"
require "pg"

database_url = if ENV["KEMAL_ENV"]? && ENV["KEMAL_ENV"] == "production"
  ENV["DATABASE_URL"]
else
  "postgres://preface@localhost:5432/kemal_sample"
end

db = DB.open(database_url)

["/", "/articles"].each do |path|
  get path do |env|
    articles = [] of Hash(String, String | Int32)
    db.query("select id, title, body from articles") do |rs|
      rs.each do
        article = {} of String => String | Int32
        article["id"] = rs.read(Int32)
        article["title"] = rs.read(String)
        article["body"] = rs.read(String)
        articles << article
      end
    end
    db.close
    render "src/views/index.ecr", "src/views/application.ecr"
  end
end

get "/articles/new" do |env|
  render "src/views/articles/new.ecr", "src/views/application.ecr"
end

post "/articles" do |env|
  title_param = env.params.body["title"]
  body_param = env.params.body["body"]
  params = [] of String
  params << title_param
  params << body_param
  db.exec("insert into articles(title, body) values($1::text, $2::text)", params)
  db.close
  env.redirect "/"
end

get "/articles/:id" do |env|
  articles = [] of Hash(String, String | Int32)
  article = {} of String => String | Int32
  id = env.params.url["id"].to_i32
  params = [] of Int32
  params << id
  article["id"], article["title"], article["body"] = db.query_one("select id, title, body from articles where id = $1::int8", params, as: {Int32, String, String})
  articles << article
  db.close
  render "src/views/articles/show.ecr", "src/views/application.ecr"
end

get "/articles/:id/edit" do |env|
  articles = [] of Hash(String, String | Int32)
  article = {} of String => String | Int32
  id = env.params.url["id"].to_i32
  params = [] of Int32
  params << id
  article["id"], article["title"], article["body"] = db.query_one("select id, title, body from articles where id = $1::int8", params, as: {Int32, String, String})
  articles << article
  db.close
  render "src/views/articles/edit.ecr", "src/views/application.ecr"
end

put "/articles/:id" do |env|
  id = env.params.url["id"].to_i32
  title_param = env.params.body["title"]
  body_param = env.params.body["body"]
  params = [] of String | Int32
  params << title_param
  params << body_param
  params << id
  db.exec("update articles set title = $1::text, body = $2::text where id = $3::int8", params)
  db.close
  env.redirect "/articles/#{id}"
end

delete "/articles/:id" do |env|
  id = env.params.url["id"].to_i32
  params = [] of Int32
  params << id
  db.exec("delete from articles where id = $1::int8", params)
  db.close
  env.redirect "/"
end

Kemal.run

```

主だった変更箇所について解説します。まずクエリは以下のように記述します。  

```crystal
db.query("select id, title, body from articles") do |rs|
  rs.each do
    article = {} of String => String | Int32
    article["id"] = rs.read(Int32)
    article["title"] = rs.read(String)
    article["body"] = rs.read(String)
    articles << article
  end
end
```

queryメソッドにSQLクエリを記述し、ループ内で結果を格納していきます。  
1件だけ取得したい場合は`query_one`もしくは`query_one?`を使います。後者は1件もデータが無い場合がありうる場合に使います。  

```crystal
article["id"], article["title"], article["body"] = db.query_one("select id, title, body from articles where id = $1::int8", params, as: {Int32, String, String})
```

query_oneの戻り値は、asで指定した型のToupleになります。  
上記の場合ですと、`Touble(Int32, String, String)`になります。

updateやdeleteの場合は`exec`メソッドを使用します。

```crystal
db.exec("update articles set title = $1::text, body = $2::text where id = $3::int8", params)
```

基本的にはあまり変更はない箇所です。


続いて画面側も一部修正します。  
具体的には`article["id"]?`のようにnilの場合の修正です。（Crystalの仕様変更に伴う修正）  

`src/views/index.ecr`
```crystal
<h2>Article List</h2>
<table class="table table-striped">
<thead>
  <tr>
    <td>title</td>
  </tr>
<tbody>
  <% articles.each do |article| %>
  <tr>
    <td><a href="/articles/<%=article["id"]? %>" target="_top"><%=article["title"]? %></a></td>
  </tr>
  <% end %>
</tbody>
</table>
```

## セッションについて

Kemalではセッションの機能を標準でサポートします。  
下記ファイルを編集し、`shards update`を実行します。

`shard.yml`
```
dependencies:
  kemal-session:
    github: kemalcr/kemal-session
```

本サンプルでは、簡単な認証機能を追加してみます。新規投稿を行う場合は認証済みのユーザでなければ出来ない（新規投稿画面に遷移できない）ようにします。

ソースを以下の内容で修正します。  
kemal-sample.crは以下の通りです。

`src/kemal-sample.cr`
```crystal
require "kemal"
require "kemal-session"
(中略)

Kemal::Session.config do |config|
  config.cookie_name = "session_id"
  config.secret = "some_secret"
  config.gc_interval = 2.minutes # 2 minutes
end

def authorized?(env)
  env.session.string?("username")
end

get "/login" do |env|
  render "src/views/login.ecr", "src/views/application.ecr"
end

post "/login" do |env|
  user_id_param = env.params.body["user_id"]
  password_param = env.params.body["password"]
  if user_id_param == "user1" && password_param == "pass1"
    env.session.string("username", "user1")
    env.redirect "/"
  else
    env.redirect "/login"
  end
end

get "/logout" do |env|
  env.session.destroy
  env.redirect "/"
end
```

ログイン画面を新規で追加します。

`src/views/login.ecr`
```
<h2>ログイン</h2>
<form method="post", action="/login">
  <input type="text" name="user_id" size="10" maxlength="10" />
  <br />
  <br />
  <input type="password" name="password" size="10" maxlength="10" />
  <br />
  <br />
  <input type="submit" value="post">
</form>

```

ヘッダの内容を変更します。

`src/views/application.ecr`
```
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>kemal sample</title>
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7" crossorigin="anonymous">
  <link rel="stylesheet" href="/css/custom.css">
</head>
<body>
<header class="navbar navbar-fixed-top navbar-inverse">
  <div class="container">
    <a id="logo">sample app</a>
    <nav>
      <ul class="nav navbar-nav navbar-right">
        <li><a href="/articles">ArticleList</a></li>
        <% if env.session.string?("username") %>
          <li><a href="/articles/new">新規投稿</a></li>
          <li><a href="/logout">ログアウト</a></li>
        <% else %>
          <li><a href="/login">ログイン</a></li>
        <% end %>
      </ul>
    </nav>
  </div>
</header>
  <div class="container">
    <%= content %>
  </div>
</body>
</html>
```

主な設定箇所について解説します。まずセッションの設定を行います。　　
```crystal
Kemal::Session.config do |config|
  config.cookie_name = "session_id"
  config.secret = "some_secret"
  config.gc_interval = 2.minutes # 2 minutes
end
```

本サンプルではcookieにセッションを保存します。`cookie_name`と`secret`でcookieの設定を行います。  
`gc_interval`で有効期間を設定します。デフォルトでは4分です。  
その他の設定は[kemal-session](https://github.com/kemalcr/kemal-session)を参照してみてください。

その他追記箇所についてはログイン、ログアウトのパスを新規で作っています。ユーザIDとパスワードの組み合わせが正しい場合はセッションを作り、そうでない場合はリダイレクトします。
本運用を考える場合は、設定をDBに持たせるなどします。

画面の方を以下の内容に修正します。

`src/views/application.ecr`より抜粋。
```
  <li><a href="/articles">ArticleList</a></li>
  <% if env.session.string?("username") %>
    <li><a href="/articles/new">新規投稿</a></li>
    <li><a href="/logout">ログアウト</a></li>
  <% else %>
    <li><a href="/login">ログイン</a></li>
  <% end %>
```

セッションの有無で表示を切り分けます。  
本稿では扱いませんが、その他ライブラリを別途使用することでRedisにセッションを保持することも可能になります。　　