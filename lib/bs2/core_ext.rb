module Kernel

  alias_method :require_without_bs2, :require
  def require(path)
    require_without_bs2(BS2[path] || path)
  rescue BS2::ReturnFalse
    return false
  end

  alias_method :load_without_bs2, :load
  def load(path, *a)
    load_without_bs2(BS2[path] || path, *a)
  rescue BS2::ReturnFalse
    return false
  end

end

class << Kernel
  alias_method :require_without_bs2, :require
  def require(path)
    require_without_bs2(BS2[path] || path)
  rescue BS2::ReturnFalse
    return false
  end

  alias_method :load_without_bs2, :load
  def load(path, *a)
    load_without_bs2(BS2[path] || path, *a)
  rescue BS2::ReturnFalse
    return false
  end
end

class Module
  alias_method :autoload_without_bs2, :autoload
  def autoload(const, path)
    autoload_without_bs2(const, BS2[path] || path)
  end
end

class << $LOAD_PATH
  %i(<< unshift push).each do |sym|
    alias_method "#{sym}_without_hack".to_sym, sym
    define_method(sym) do |lpe|
      BS2.load_path_added(lpe)
      send("#{sym}_without_hack", lpe)
    end
  end
end
