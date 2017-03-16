module Bootsnap
  module LoadPathCache
    module ChangeObserver
      def self.register(observer, arr)
        return if arr.respond_to?(:push_without_lpc)

        sc = arr.singleton_class
        sc.send(:alias_method, :shovel_without_lpc, :<<)
        arr.define_singleton_method(:<<) do |entry|
          observer.push_paths(self, entry)
          shovel_without_lpc(entry)
        end

        sc.send(:alias_method, :push_without_lpc, :push)
        arr.define_singleton_method(:push) do |*entries|
          observer.push_paths(self, *entries)
          push_without_lpc(*entries)
        end

        sc.send(:alias_method, :unshift_without_lpc, :unshift)
        arr.define_singleton_method(:unshift) do |*entries|
          observer.unshift_paths(self, *entries)
          unshift_without_lpc(*entries)
        end

        sc.send(:alias_method, :concat_without_lpc, :concat)
        arr.define_singleton_method(:concat) do |entries|
          observer.push_paths(self, *entries)
          concat_without_lpc(entries)
        end

        # Rails calls `uniq!` on the load path, and we don't prevent it. It's mostly
        # harmless as far as our accounting goes.

        # #+ is not inherently destructive, but the most common use is for #+=,
        # which defeats our hooks.
        %i(
          collect! compact! delete delete_at delete_if fill flatten! insert map!
          reject! reverse! select! shuffle! shift slice! sort! sort_by!
        ).each do |meth|
          sc.send(:alias_method, :"#{meth}_without_lpc", meth)
          arr.define_singleton_method(meth) do |*a|
            send(:"#{meth}_without_lpc", *a)
            observer.reinitialize
          end
        end
      end
    end
  end
end
