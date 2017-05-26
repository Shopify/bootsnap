# *(unreleased)*

* Don't whitelist paths under `RbConfig::CONFIG['prefix']` as stable; instead use `['libdir']` (#41).

# 0.3.0

* Migrate CompileCache from xattr as a cache backend to a cache directory
    * Adds support for Linux and FreeBSD

# 0.2.15

* Support more versions of ActiveSupport (`depend_on`'s signature varies; don't reiterate it)
* Fix bug in handling autoloaded modules that raise NoMethodError
