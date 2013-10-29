require 'kit/worker'
require 'sidetiq'

module Kit
  class Worker
    class Import < Worker

      include Sidetiq::Schedulable

      recurrence { weekly.day(:monday) }

      def perform
        super 'chairman', 'launch', 'app', 'importer'
      end
    end
  end
end
