
require "em-dir-watcher/invokers/subprocess_invoker"

module EMDirWatcher
module Platform
module Mac

class Watcher

    STARTUP_DELAY = 0.5

    attr_accessor :handler, :active

    def initialize path, inclusions, exclusions
        update_last_event

        subprocess = lambda do |ready, output|
            require 'rb-fsevent'
            stream = FSEvent.new
            stream.watch path do |directories|
              files = find_changed_files(directories, {:all => true})
              files.each { |path|
                output.call path
              }
            end

            ready.call()
            stream.run
        end

        @invoker = EMDirWatcher::Invokers::SubprocessInvoker.new subprocess do |path|
            code, path = path[0], path[1..-1]
            if code == ?> || code == ?-
                refresh_subtree = (code == ?>)
                yield path, refresh_subtree
            end
        end
        # Mac OS X seems to require this delay till it really starts listening for file system changes.
        # See README for explaination of the effect.
        @invoker.additional_delay = STARTUP_DELAY
    end

    def when_ready_to_use &ready_to_use_handler
        @invoker.when_ready_to_use &ready_to_use_handler
    end

    def ready_to_use?; true; end

    def stop
        @invoker.stop
    end

    # Copy/paste from https://github.com/guard/guard/blob/a21bb8e306e44fd153c8b88a7c59c00e451b1d52/lib/guard/listener.rb#L34-54
    private

      def find_changed_files(dirs, options = {})
        files = potentially_changed_files(dirs, options).select { |path| File.file?(path) && changed_file?(path) }
        files.map! { |file| file.gsub("#{Dir.pwd}/", '') }
      end

      def potentially_changed_files(dirs, options = {})
        match = options[:all] ? "**/*" : "*"
        result = Dir.glob(dirs.map { |dir| "#{dir}#{match}" })
        result
      end

      def changed_file?(file)
        File.mtime(file) >= @last_event
      rescue
        false
      end

      def update_last_event
        @last_event = Time.now
      end

end
end
end
end
