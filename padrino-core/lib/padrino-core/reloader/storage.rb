module Padrino
  module Reloader
    module Storage
      extend self

      def clear!
        files.each_key do |file|
          remove(file)
          Reloader.remove_feature(file)
        end
        @files = {}
      end

      def remove(name)
        file = files[name] || return
        file[:constants].each{ |constant| Reloader.remove_constant(constant) }
        file[:features].each{ |feature| Reloader.remove_feature(feature) }
        files.delete(name)
      end

      def prepare(name)
        file = remove(name)
        update_constants_cache(name)
        features = file && file[:features] || []
        features.each{ |feature| Reloader.safe_load(feature, :force => true) }
        Reloader.remove_feature(name) if old_features(name).include?(name)
      end

      def commit(name)
        entry = {
          :constants => new_constants = ObjectSpace.new_classes(old_entries[name][:constants]),
          :features  => Set.new($LOADED_FEATURES) - old_entries[name][:features] - [name]
        }
        constants.merge(new_constants)
        files[name] = entry
        old_entries.delete(name)
      end

      def rollback(name)
        new_constants = ObjectSpace.new_classes(old_entries[name][:constants])
        new_constants.each{ |klass| Reloader.remove_constant(klass) }
        constants.clear
        old_entries.delete(name)
      end

      private

      def files
        @files ||= {}
      end

      def prepare_old_entry(name, constants)
        old_entries[name] = {
          :constants => constants,
          :features  => Set.new($LOADED_FEATURES.dup)
        }
      end

      def update_constants_cache(name)
        constants.merge(ObjectSpace.classes) if constants.empty?
        prepare_old_entry(name, constants)
      end

      def old_features(name)
        old_entries[name][:features]
      end

      def constants
        @constants ||= Set.new
      end

      def old_entries
        @old_entries ||= {}
      end
    end
  end
end
