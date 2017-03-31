# Bootsnap

**Beta-quality. See the last section of this README.**

Bootsnap is a library that overrides `Kernel#require`, `Kernel#load`, `Module#autoload` and in the case that `ActiveSupport` is used a number of `ActiveSupport` methods, with a fast cache that increases boot performance.

Bootsnap creates 2 kinds of caches, a stable, long lived cache out of Ruby and Gem directories. These are assumed to never change and so we can cache more aggresively. Application code is expected to change frequently, so it is cached with little aggression (short lived bursts that should last only as long as the app takes to boot). This is the “volatile” cache.

Below is a diagram explaining how the overrides work.

![Flowchart explaining Bootsnap](https://cloud.githubusercontent.com/assets/3074765/24532120/eed94e64-158b-11e7-9137-438d759b2ac8.png)

In this diagram, you might notice that we refer to cache and autoload_path_cache as the main points of override. 

# How it works

Caching paths is the main function of bootsnap. There are 2 types of caches:

- Stable: For Gems and Rubies since these are highly unlikely to change
- Volatile: For everything else, like your app code, since this is likely to change

This path is shown in the flowchart below. In a number of instances, scan is mentioned. 

![How path searching works](https://cloud.githubusercontent.com/assets/3074765/24532143/18278cd6-158c-11e7-8250-78d831df70db.png)

# Usage

Add `bootsnap` to your `Gemfile`:

```ruby
gem 'bootsnap'
```

Next, add this to your boot setup right after `require 'bundler/setup'`, to maximize the benefits of the optimizations.

```ruby
require 'bootsnap'
Bootsnap.setup(
  cache_dir:            'tmp/cache',                      ## Path to your cache
  development_mode:     ENV['MY_ENV'] == 'development',
  load_path_cache:      true,                             ## Should we optimize the LOAD_PATH with a cache?
  autoload_paths_cache: true,                             ## Should we optimize the AUTOLOAD_PATH with a cache?
  disable_trace:        false,                            ## Sets `RubyVM::InstructionSequence.compile_option = { trace_instruction: false }`
  compile_cache_iseq:   true,                             ## Should compile Ruby code into iSeq cache?
  compile_cache_yaml:   true                              ## Should compile YAML into a cache?
)
```

**Protip:** You can replace `require 'bootsnap'` with `BootLib::Require.from_gem('bootsnap', 'bootsnap')` using [this trick](https://github.com/Shopify/bootsnap/wiki/Bootlib::Require). This will help optimize boot time.

### How likely is this to work?

We use the `*_path_cache` features in production and haven't experienced any issues in a long time.

The `compile_cache_*` features work well for us in development on macOS, but probably don't work on
linux at all.

`disable_trace` should be completely safe, but we don't really use it because some people like to
use tools that make use of `trace` instructions.

| feature | where we're using it |
|-|-|
| `load_path_cache` | everywhere |
| `autoload_path_cache` | everywhere |
| `disable_trace` | nowhere, but it's safe unless you need tracing |
| `compile_cache_iseq` | development |
| `compile_cache_yaml` | development |
