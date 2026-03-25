Alba.backend = :oj
Alba.inflector = :active_support

# Custom types
Alba.register_type :iso8601, converter: ->(time) { time&.iso8601(3) }, auto_convert: true

begin
  require 'typelizer/serializer_plugins/alba'
  module Typelizer
    module SerializerPlugins
      class Alba
        unless method_defined?(:original_ts_mapper)
          alias_method :original_ts_mapper, :ts_mapper
          def ts_mapper
            original_ts_mapper.merge('iso8601' => { type: 'string' })
          end
        end
      end
    end
  end
rescue LoadError
  # typelizer not in bundle, safely ignore
end
