module PaperTrail
  # :nodoc:
  module AttributeSerializers
    # The `CastAttributeSerializer` (de)serializes model attribute values. For
    # example, the string "1.99" serializes into the integer `1` when assigned
    # to an attribute of type `ActiveRecord::Type::Integer`.
    #
    # This implementation depends on the `type_for_attribute` method, which was
    # introduced in rails 4.2. In older versions of rails, we shim this method
    # with `LegacyActiveRecordShim`.
    if ::ActiveRecord::VERSION::MAJOR >= 5
      # This implementation uses AR 5's `serialize` and `deserialize`.
      class CastAttributeSerializer
        def initialize(klass)
          @klass = klass
        end

        def serialize(attr, val)
          unless defined_enums[attr]
            @klass.type_for_attribute(attr).serialize(val)
          end

          val
        end

        def deserialize(attr, val)
          unless defined_enums[attr]
            @klass.type_for_attribute(attr).deserialize(val)
          end

          val
        end
      end
    else
      # This implementation uses AR 4.2's `type_cast_for_database`. For
      # versions of AR < 4.2 we provide an implementation of
      # `type_cast_for_database` in our shim attribute type classes,
      # `NoOpAttribute` and `SerializedAttribute`.
      class CastAttributeSerializer
        def initialize(klass)
          @klass = klass
        end

        def serialize(attr, val)
          castable_val = val
          if defined_enums[attr]
            # `attr` is an enum. Find the number that corresponds to `val`. If `val` is
            # a number already, there won't be a corresponding entry, just use `val`.
            castable_val = defined_enums[attr][val] || val
          end
          @klass.type_for_attribute(attr).type_cast_for_database(castable_val)
        end

        def deserialize(attr, val)
          val = @klass.type_for_attribute(attr).type_cast_from_database(val)
          if defined_enums[attr]
            defined_enums[attr].key(val)
          else
            val
          end
        end

        private

        # ActiveRecord::Enum was added in AR 4.1
        # http://edgeguides.rubyonrails.org/4_1_release_notes.html#active-record-enums
        def defined_enums
          @defined_enums ||= (@klass.respond_to?(:defined_enums) ? @klass.defined_enums : {})
        end
      end
    end
  end
end
