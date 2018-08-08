require "active_support/concern"

module DistributeReads
  module JobMethods
    extend ActiveSupport::Concern

    included do
      before_perform do
        if DistributeReads.by_default
          if DistributeReads.makara3?
            Makara::Context.set_current(Makara::Context.generate)
          else
            Makara::Context.release_all
          end
        end
      end
    end

    class_methods do
      def distribute_reads(*args)
        around_perform do |_job, block|
          distribute_reads(*args) { block.call }
        end
      end
    end
  end
end
