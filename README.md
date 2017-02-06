# BootSnap

BootSnap is a suite of hacks to make (large) ruby applications boot faster.

There are two main features:

1. Caching compiled Ruby and YAML to save load time on subsequent boots.
2. Pre-scanning the `$LOAD_PATH` and intercepting calls to `require`,
   subsituting the full path (eliminating frequent traversals of the full
   `LOAD_PATH`) via the dependency on
   [`bootscale`](https://github.com/byroot/bootscale).

---

Ruby spends a lot of time compiling source to bytecode, and a lot of Rails apps
spend quite a bit of time parsing yaml. The majority of that code and data
stays the same across many boots.

BootSnap caches the results of those compilation (as a binary ISeq for
ruby, and as MessagePack or Marshal for YAML) in extended filesystem attributes.

This is what a successful cache hit looks like in strace/dtruss:

```
open("/path/to/file.rb", 0x2, 0x5)		 = 7 0
fstat64(0x7, 0x7FFF57927728, 0x5)		 = 0 0
fgetxattr(0x7, 0x108B51E10, 0x7FFF579277B8)		 = 25 0
fgetxattr(0x7, 0x108B51E28, 0x7FD00F86F000)		 = 3626 0
close(0x7)		 = 0 0
```

The data fetched from the xattr is the compiled bytecode/messagepack.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bootsnap'
```

Then, immediatley after `require "bundler/setup"` in your `config/boot.rb` or
whatever it is that initializes your application:

```ruby
require 'bootsnap'
BootSnap.setup(
  cache_dir: File.expand_path('../../tmp', __FILE__),
  development_mode: ENV['ENV'] != "production",
)
```

You can opt out of specific features by passing additional flags to `BootSnap.setup`. For example:

```ruby
require 'bootsnap'
BootSnap.setup(
  cache_dir: File.expand_path('../../tmp', __FILE__),
  development_mode: ENV['ENV'] != "production",
  iseq: false,
  yaml: true,
  require: false,
  as_autoload: false,
)
```

