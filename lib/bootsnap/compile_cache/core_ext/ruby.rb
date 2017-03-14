RubyVM::InstructionSequence.singleton_class.prepend(Module.new do
  def load_iseq(path)
    Bootsnap::CompileCache.ruby_compile_cache.fetch(path.to_s)
  end

  def compile_option=(hash)
    super(hash)
    Bootsnap::CompileCache.ruby_compile_cache.compile_option_updated
  end
end)
