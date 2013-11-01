require 'kit/worker'
require 'sidetiq'

module Kit
  class Worker
    class Export < Worker

      include Sidetiq::Schedulable

      recurrence { weekly.day(:tuesday) }

      def perform
        super 'chairman', 'launch', 'app', 'exporter'
      end
    end
  end
end
