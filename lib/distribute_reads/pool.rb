module DistributeReads
  module Pool
    def initialize(*)
      super
      @replica = @role == "slave"
      @named_wrappers = {} if @replica
    end

    def add(config)
      wrapper = super
      @named_wrappers[config[:name]] = wrapper if @replica
      wrapper
    end

    # TODO probably safer to use separate method for this
    def completely_blacklisted?
      return super unless @replica

      wrapper = named_wrapper
      if wrapper
        wrapper._makara_blacklisted?
      else
        super
      end
    end

    protected

    def next
      return super unless @replica

      wrapper = named_wrapper
      if wrapper
        wrapper._makara_blacklisted? ? nil : wrapper
      else
        super
      end
    end

    def named_wrapper
      if (name = Thread.current[:distribute_reads] && Thread.current[:distribute_reads][:name])
        wrapper = @named_wrappers[name.to_s]
        raise ArgumentError, "Unknown replica: #{name}" unless wrapper
        wrapper
      end
    end
  end
end
