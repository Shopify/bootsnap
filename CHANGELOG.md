# Unreleased

# 1.7.4

* Stop raising errors when encoutering various file system errors. The cache is now best effort,
  if somehow it can't be saved, bootsnapp will gracefully fallback to the original operation (e.g. `Kernel.require`).
  (#353, #177, #262)

# 1.7.3

* Disable YAML precompilation when encountering YAML tags. (#351)

# 1.7.2

* Fix compatibility with msgpack < 1. (#349)

# 1.7.1

* Warn Ruby 2.5 users if they turn ISeq caching on. (#327, #244)
* Disable ISeq caching for the whole 2.5.x series again.
* Better handle hashing of Ruby strings. (#318)

# 1.7.0

* Fix detection of YAML files in gems.
* Adds an instrumentation API to monitor cache misses.
* Allow to control the behavior of `require 'bootsnap/setup'` using environment variables.
* Deprecate the `disable_trace` option.
* Deprecate the `ActiveSupport::Dependencies` (AKA Classic autoloader) integration. (#344) 

# 1.6.0

* Fix a Ruby 2.7/3.0 issue with `YAML.load_file` keyword arguments. (#342)
* `bootsnap precompile` CLI use multiple processes to complete faster. (#341)
* `bootsnap precompile` CLI also precompile YAML files. (#340)
* Changed the load path cache directory from `$BOOTSNAP_CACHE_DIR/bootsnap-load-path-cache` to `$BOOTSNAP_CACHE_DIR/bootsnap/load-path-cache` for ease of use. (#334)
* Changed the compile cache directory from `$BOOTSNAP_CACHE_DIR/bootsnap-compile-cache` to `$BOOTSNAP_CACHE_DIR/bootsnap/compile-cache` for ease of use. (#334)

# 1.5.1

* Workaround a Ruby bug in InstructionSequence.compile_file. (#332)

# 1.5.0

* Add a command line to statically precompile the ISeq cache. (#326)

# 1.4.9

* [Windows support](https://github.com/Shopify/bootsnap/pull/319)
* [Fix potential crash](https://github.com/Shopify/bootsnap/pull/322)

# 1.4.8

* [Prevent FallbackScan from polluting exception cause](https://github.com/Shopify/bootsnap/pull/314)

# 1.4.7

* Various performance enhancements
* Fix race condition in heavy concurrent load scenarios that would cause bootsnap to raise

# 1.4.6

* Fix bug that was erroneously considering that files containing `.` in the names were being
  required if a different file with the same name was already being required

  Example:
  
      require 'foo'
      require 'foo.en'

  Before bootsnap was considering `foo.en` to be the same file as `foo`

* Use glibc as part of the ruby_platform cache key

# 1.4.5

* MRI 2.7 support
* Fixed concurrency bugs

# 1.4.4

* Disable ISeq cache in `bootsnap/setup` by default in Ruby 2.5

# 1.4.3

* Fix some cache permissions and umask issues after switch to mkstemp

# 1.4.2

* Fix bug when removing features loaded by relative path from `$LOADED_FEATURES`
* Fix bug with propagation of `NameError` up from nested calls to `require`

# 1.4.1

* Don't register change observers to frozen objects.

# 1.4.0

* When running in development mode, always fall back to a full path scan on LoadError, making
  bootsnap more able to detect newly-created files. (#230)
* Respect `$LOADED_FEATURES.delete` in order to support code reloading, for integration with
  Zeitwerk. (#230)
* Minor performance improvement: flow-control exceptions no longer generate backtraces.
* Better support for requiring from environments where some features are not supported (especially
  JRuby). (#226)k
* More robust handling of OS errors when creating files. (#225)

# 1.3.2

* Fix Spring + Bootsnap incompatibility when there are files with similar names.
* Fix `YAML.load_file` monkey patch to keep accepting File objects as arguments.
* Fix the API for `ActiveSupport::Dependencies#autoloadable_module?`.
* Some performance improvements.

# 1.3.1

* Change load path scanning to more correctly follow symlinks.

# 1.3.0

* Handle cases where load path entries are symlinked (https://github.com/Shopify/bootsnap/pull/136)

# 1.2.1

* Fix method visibility of `Kernel#require`.

# 1.2.0

* Add `LoadedFeaturesIndex` to preserve fix a common bug related to `LOAD_PATH` modifications after
  loading bootsnap.

# 1.1.8

* Don't cache YAML documents with `!ruby/object`
* Fix cache write mode on Windows

# 1.1.7

* Create cache entries as 0775/0664 instead of 0755/0644
* Better handling around cache updates in highly-parallel workloads

# 1.1.6

* Assortment of minor bugfixes

# 1.1.5

* bugfix re-release of 1.1.4

# 1.1.4 (yanked)

* Avoid loading a constant twice by checking if it is already defined

# 1.1.3

* Properly resolve symlinked path entries

# 1.1.2

* Minor fix: deprecation warning

# 1.1.1

* Fix crash in `Native.compile_option_crc32=` on 32-bit platforms.

# 1.1.0

* Add `bootsnap/setup`
* Support jruby (without compile caching features)
* Better deoptimization when Coverage is enabled
* Consider `Bundler.bundle_path` to be stable

# 1.0.0

* (none)

# 0.3.2

* Minor performance savings around checking validity of cache in the presence of relative paths.
* When coverage is enabled, skips optimization instead of exploding.

# 0.3.1

* Don't whitelist paths under `RbConfig::CONFIG['prefix']` as stable; instead use `['libdir']` (#41).
* Catch `EOFError` when reading load-path-cache and regenerate cache.
* Support relative paths in load-path-cache.

# 0.3.0

* Migrate CompileCache from xattr as a cache backend to a cache directory
    * Adds support for Linux and FreeBSD

# 0.2.15

* Support more versions of ActiveSupport (`depend_on`'s signature varies; don't reiterate it)
* Fix bug in handling autoloaded modules that raise NoMethodError
