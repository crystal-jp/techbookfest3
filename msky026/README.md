Title: CrystalとWeb 2
Author: msky
Twitter: @msky026

# はじめに

1年前の技術書典1で「CrystalとWeb」について記述しました。  
CrystalやKemalもそれから多くの点で変更になりましたが、本稿では主にDBの扱い方について解説します。

# Kemalの変更点

## DB接続設定の変更

まず主だった変更点として、DB接続を行うモジュールが変更されましｔ。  
以前はPostgreSQLを使用する際はkemal-pgを使ってDBに接続していましたが、DB接続関連は[crystal-db](https://github.com/crystal-lang/crystal-db)のライブラリがデファクトスタンダードになっています。こちらのライブラリは現時点でコネクションプールも備えております。  
以前はコネクションプール使用時には専用のライブラリを使用していましたがそれも不要になりました。  

以下に変更点について記載していきます。変更点のみの記述となりますが、全体像が見たい方は、[kemal-sample](https://github.com/msky026/kemal-sample)を参照してみてください。  
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

