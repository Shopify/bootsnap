# BootSnap

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

Then, add, as early as possible in your application's boot process:

```ruby
require 'bootsnap/iseq'
require 'bootsnap/yaml'
```

Usually the best place for this is immediately after `require 'bundler/setup'`.
