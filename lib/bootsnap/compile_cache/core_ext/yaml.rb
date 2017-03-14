module YAML
  def self.load_file(path)
    Bootsnap::CompileCache.yaml_compile_cache.fetch(path.to_s)
  end
end
