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
