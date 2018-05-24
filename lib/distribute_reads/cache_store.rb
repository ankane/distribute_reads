module DistributeReads
  class CacheStore
    def read(key)
      memory_cached = memory_store.read(key)
      return nil if memory_cached == :nil
      return memory_cached if memory_cached

      store_cached = store.try(:read, key)
      memory_store.write(key, store_cached || :nil)
      store_cached
    end

    def write(*args)
      memory_store.write(*args)
      store.try(:write, *args)
    end

    private

    # use ActiveSupport::Cache::MemoryStore instead?
    def memory_store
      @memory_store ||= Makara::Cache::MemoryStore.new
    end

    def store
      @store ||= Rails.cache
    end
  end
end
