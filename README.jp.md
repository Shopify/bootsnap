# Bootsnap [![Build Status](https://travis-ci.org/Shopify/bootsnap.svg?branch=master)](https://travis-ci.org/Shopify/bootsnap)

Bootsnapとは、 激しいコンピューテイションを最適化、そしてキャッシュするRubyのライブラリーです。ActiveSupport や YAMLもサポートできます。詳しくは使用方法をご覧ください。

注意書き: このライブラリーは英語話者によって管理されています。このREADMEは日本語ですが、日本語でのサポートはできませんし、リクエストにお答えすることもできません。バイリンガルの方がサポートをサポートしてくださる場合はお知らせください！:)

##パフォーマンス

Discourse では、あるコンピューターで約6秒から3秒まで、つまり約50%の起動時間の短縮をリポートしています。
より小さな内部アプリの1つにも、3.6秒から1.8秒までの50%の短縮が見られます。
かなり広大でモノリシックなアプリであるShopifyのプラットフォームも約25秒から6.5秒へと約75％速くなります。

## 使用方法

bootsnapはMacOSそしてLinuxで作動できます。

まずはbootsnap をGemfileに導入します。:

```ruby
gem 'bootsnap', require: false
```

レールを使用している場合は、 以下のコードを`require 'bundler / setup'`の後の`config / boot.rb`に追加してください。

```ruby
require 'bootsnap/setup'
```

レールを使用していない場合、または使用していてもより多くをコントロールしたい場合は、以下のコードを`require 'bundler/setup'`の直後にあなたのアプリ設定に加えてください(つまり、早く読み込まれるほど、早く最適化することができます。）。

```ruby
require 'bootsnap'
env = ENV['RAILS_ENV'] || "development"
Bootsnap.setup(
  cache_dir:            'tmp/cache',          # キャッシュへの経路
  development_mode:     env == 'development', # 現在の作業環境、例えばRACK_ENV, RAILS_ENVなど。
  load_path_cache:      true,                 # キャッシュで LOAD_PATHを最適化する。
  autoload_paths_cache: true,                 # キャッシュでActiveSupport自動ロードする。 
  disable_trace:        true,                 # (アルファ) `RubyVM::InstructionSequence.compile_option = { trace_instruction: false }`をセットする。
  compile_cache_iseq:   true,                 # ISeq キャッシュにRubyコードを編入する。
  compile_cache_yaml:   true                  # YAMLをキャッシュに編入する。
)
```

ヒント: `require 'bootsnap'`を `BootLib::Require.from_gem('bootsnap', 'bootsnap')` で、 [こちらのトリック]を使って置き換えることができます。(https://github.com/Shopify/bootsnap/wiki/Bootlib::Require)こうすると、巨大な`$LOAD_PATH`がある場合でも、起動時間を最短化するのに役立ちます。

## Bootsnapはどう動作するのですか？

Bootsnapは、高価なコンピューテイションの結果をキャッシュするためのメソッドを最適化し、2つカテゴリーに分けられます。

- Path Pre-Scanning

  - Kernel#require と Kernel#loadが $LOAD_PATH スキャンを抹消するために変更されます。
  - `ActiveSupport::Dependencies.{autoloadable_module?,load_missing_constant,depend_on}`は`ActiveSupport::Dependencies.autoload_paths`のスキャンを抹消するためにオーバーライドされます。

### Compilation caching

  - `RubyVM::InstructionSequence.load_iseq` が、Rubyバイトコードのcompilationの結果をキャッシュするために実施されます。
  - `YAML.load_file`が、 MessagePack 型式にYAMLobjectのロード結果をキャッシュするために変更されます。 あるいは、メッセージがMessagePackにサポートされていないタイプを使う場合はMarshalになります。

### Path Pre-Scanning

この作業はbootscaleのわずかな進化です。

Bootsnapの始動時、あるいは経路(例えば、`$LOAD_PATH`)の変更時に、 `Bootsnap::LoadPathCache` は、キャッシュから必要なエントリーのリストを読み込むか、必要に応じてフルスキャンを実行し、結果をキャッシュします。
その後、 例えば require 'foo'を作動する場合, Rubyは`$LOAD_PATH` ['x', 'y', ...]のすべての項目を繰り返し処理をします。そしてx/foo.rb, y/foo.rbなどを探すのです。これに対してBootsnapは、各`$LOAD_PATH`エントリーのすべてのキャッシュされた必要事項を調べ、Rubyが最終的に選択したかもしれないマッチの完全に拡大された経路で置き換えます。
この動作によって生成されたsyscallを見ると、最終的効果は以前なら次のようでした。

```
open  x/foo.rb # (fail)
# (imagine this with 500 $LOAD_PATH entries instead of two)
open  y/foo.rb # (success)
close y/foo.rb
open  y/foo.rb
...
```

これが、次のようになります:

```
open y/foo.rb
...
```

`autoload_paths_cache` オプションが `Bootsnap.setup`に与えられている場合、`ActiveSupport::Dependencies.autoload_paths` をトラバースするメソッドにはまったく同じ戦略が使用されます。

次の流れ図が`*_path_cache` 機能を作動させるオーバーライドを説明します。

![Bootsnapを説明する流れ図](https://cloud.githubusercontent.com/assets/3074765/24532120/eed94e64-158b-11e7-9137-438d759b2ac8.png)

Bootsnapは、経路エントリーを安定と不安定の2つのカテゴリに分類します。不安定エントリーはアプリケーションが起動するたびにスキャンされ、そのキャッシュは30秒間だけ有効です。安定エントリーに期限切れはありません。コンテンツがスキャンされると、決して変更されないものとみなされます。

安定していると考えられる唯一のディレクトリーは、Rubyのインストール プレフィックス (`RbConfig::CONFIG['prefix']`, または`/usr/local/ruby` や`~/.rubies/x.y.z`)下にあるものと、`Gem.path` (例えば`~/.gem/ruby/x.y.z`) や`Bundler.bundle_path`下にあるものです。他のすべては不安定と考えられます。

に加えて、この図はエントリ―の解決がどのように機能するかを明確にするのに役立つかもしれません。
経路検索は以下のようになります　

![パス検索の仕組み](https://cloud.githubusercontent.com/assets/3074765/25388270/670b5652-299b-11e7-87fb-975647f68981.png)

また、 `LoadError`のスキャンがどれほど高価なものかに注意を払うことも大切です。もしRubyが`require 'something'`を発動し、しかしそのファイルが`$LOAD_PATH`にない場合はそれを定めるのに `2 * $LOAD_PATH.length`ファイルシステム アクセルが必要になります。Bootsnapは、ファイルシステムにまったく触れずに`LoadError`を掲げ、この結果をキャッシュします。

## Compilation Caching

このコンセプトのより読み易い実施方法は 読み込むにあります。
Rubyには複雑な文法や構文解析があり、特に安いオペレーションではありません。1.9以降、RubyはRubyソースを内部のバイトコード形式に変換した後、Ruby VMによって実行されてきました。2.3.0以降、[RubyはAPIを公開し](https://ruby-doc.org/core-2.3.0/RubyVM/InstructionSequence.html）そのバイトコードをキャッシュすることができます。これにより、同じファイルの後続のロード時の比較的高価な編集ステップをバイパスすることができるのです。

また、私たちはアプリケーションの起動時にYAMLドキュメントの読み込みに多くの時間を費やしていること、そしてMessagePackとMarshalはdeserializationにあたってYAML (速い実行時ですら)よりもはるかに高速であるということに気付きました。私たちはYAMLドキュメントのコンパイル キャッシングの同じ戦略を使用しています。Rubyの "バイトコード" フォーマットに相当するものはMessagePackドキュメント (あるいは、MessagePackにサポートされていないタイプの YAMLドキュメントの場合は、Marshal stream)です。

これらのコンパイル結果は、入力ファイル（FNV1a-64）の完全な拡張経路のハッシュを取って生成されたファイル名で、キャッシュディレクトリに保存されます。

以前は、ファイルを「要求する」ために生成されたsyscallの順序は、次のようでした:

```
open    /c/foo.rb -> m
fstat64 m
close   m
open    /c/foo.rb -> o
fstat64 o
fstat64 o
read    o
read    o
...
close   o
```

しかしBootsnapでは、次のようになります:

```
open      /c/foo.rb -> n
fstat64   n
close     n
open      /c/foo.rb -> n
fstat64   n
open      (cache) -> m
read      m
read      m
close     m
close     n
```

これは一目見るだけでは劣化していると思われるかもしれませんが、性能に大きな違いがあります。
両方のリストの最初の3つのsyscalls -- `open`, `fstat64`, `close` -- は本質的に有用ではありません。このRubyパッチ は、Boosnapと組み合わせることによって、それらを最適化します。

Bootsnapは、64バイトのヘッダーとそれに続くキャッシュの内容を含んだキャッシュファイルを書き込みます。ヘッダーは、次のいくつかのフィールドを含むキャッシュ キーです。
 - `version`、Bootsnapにハードコードされています。基本的にスキーマのバージョン;
 - `os_version`、(macOS, BSDの) 現在のカーネル バージョンか 、(Linuxの) glibc のバージョンのハッシュ;
- `compile_option`、`RubyVM::InstructionSequence.compile_option` と共に変わる
- `ruby_revision`、これがコンパイルされたRubyのバージョン;
- `size`、ソース ファイルのサイズ;
- `mtime`、コンパイル時のソース ファイルの最終変更タイムスタンプ; そして
- `data_size`、バッファに読み込む必要のある、ヘッダーに続くバイト数。

キーが有効な場合、結果は値からロードされます。さもなければ、それは再生成され、現在のキャッシュを閉鎖します。
すべてを合成すると
次のファイル構造があると想像してみてください:

```
/
├── a
├── b
└── c
    └── foo.rb
```

そして、これ `$LOAD_PATH`:

```
["/a", "/b", "/c"]
```

Bootsnapなしで`require 'foo'`を呼び出すと、Rubyは次の順序でsyscallsを生成します:

```
open    /a/foo.rb -> -1
open    /b/foo.rb -> -1
open    /c/foo.rb -> n
close   n
open    /c/foo.rb -> m
fstat64 m
close   m
open    /c/foo.rb -> o
fstat64 o
fstat64 o
read    o
read    o
...
close   o
```

しかしBootsnapでは、次のようになります:

```
open      /c/foo.rb -> n
fstat64   n
close     n
open      /c/foo.rb -> n
fstat64   n
open      (cache) -> m
read      m
read      m
close     m
close     n
```

Bootsnapなしで`require 'nope'`を呼び出すと、次のようになります:

```
open    /a/nope.rb -> -1
open    /b/nope.rb -> -1
open    /c/nope.rb -> -1
open    /a/nope.bundle -> -1
open    /b/nope.bundle -> -1
open    /c/nope.bundle -> -1
```

...そして、Bootsnapで`require 'nope'`を呼び出すと、次のようになります...

```
# (nothing!)
```
