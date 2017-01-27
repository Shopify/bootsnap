require 'aot_compile_cache/iseq'

path = "/Users/burke/src/github.com/Shopify/shopify/config/environments/development.rb"
data = AOTCompileCache::Native.fetch(path, AOTCompileCache::ISeq)
puts data.inspect
