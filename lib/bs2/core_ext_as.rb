require 'active_support/dependencies'

module ActiveSupport
  module Dependencies
    # ActiveSupport::Dependencies.search_for_file works pretty much like Kernel#require.
    # It has a load path (AS::Dependencies.autoload_paths) and when it's looking for a file to load
    # it search the load path entries one by one for a match.
    # So just like for Kernel#require, this process is increasingly slow the more load path entries you have,
    # and it can be optimized with exactly the same caching strategy.
    alias_method :search_for_file_without_bs2, :search_for_file
    def search_for_file(path)
      BS2AS[path] || search_for_file_without_bs2(path)
    rescue BS2AS::ReturnFalse
      return false
    end
  end
end

class << ActiveSupport::Dependencies.autoload_paths
  %i(unshift).each do |sym|
    alias_method "#{sym}_without_hack".to_sym, sym
    define_method(sym) do |*lpes|
      lpes.reverse.each do |lpe|
        BS2AS.load_path_added(lpe, true)
        send("#{sym}_without_hack", lpe)
      end
    end
  end
  %i(<< push).each do |sym|
    alias_method "#{sym}_without_hack".to_sym, sym
    define_method(sym) do |lpe|
      BS2AS.load_path_added(lpe, false)
      send("#{sym}_without_hack", lpe)
    end
  end
end
