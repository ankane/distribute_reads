module DistributeReads
  module Pool
    # Added a new method to define the name of the replicate to be used on the Makara NameSelect strategy.
    def current_name=(connection_name)
      return unless @strategy.respond_to?(:current_name=)
      @strategy.current_name = connection_name
    end
  end
end
