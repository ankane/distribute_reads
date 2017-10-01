require "active_support/concern"

module DistributeReads
  module JobMethods
    extend ActiveSupport::Concern

    included do
      before_perform do
        Makara::Context.set_current(Makara::Context.generate) if DistributeReads.by_default
      end
    end

    class_methods do
      def distribute_reads(*args)
        around_perform do |job, block|
          distribute_reads(*args) { block.call }
        end
      end
    end
  end
end
