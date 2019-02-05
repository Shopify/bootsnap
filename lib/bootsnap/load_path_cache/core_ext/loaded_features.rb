class << $LOADED_FEATURES
  alias_method(:delete_without_bootsnap, :delete)
  def delete(key)
    Bootsnap::LoadPathCache.loaded_features_index.purge(key)
    delete_without_bootsnap(key)
  end
end
