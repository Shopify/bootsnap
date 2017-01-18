require 'aot_compile_cache/version'
require 'aot_compile_cache/aot_compile_cache'

# These don't benefit from the ISeq patch, so keep the list short.
require 'fiddle'
require 'fileutils'

# These are loaded in config/boot.rb after applying the ISeq patch.
#   require 'yaml'

class AOTCompileCache
end
