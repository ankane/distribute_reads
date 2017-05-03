module DistributeReads
  module JobMethods
    def distribute_reads(mode = true, max_lag: nil)
      around_perform do |job, block|
        distribute_reads(mode, max_lag: max_lag) { block.call }
      end
    end
  end
end
