module DistributeReads
  module JobMethods
    def distribute_reads
      around_perform do |job, block|
        distribute_reads { block.call }
      end
    end
  end
end
