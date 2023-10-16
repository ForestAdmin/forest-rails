# encoding: UTF-8
module ForestLiana
  class Logger
    class << self
      def log
        if ForestLiana.logger != nil
          logger = ForestLiana.logger
        else
          logger = ::Logger.new(STDOUT)
          logger_colors = {
            DEBUG: 34,
            WARN: 33,
            ERROR: 31,
            INFO: 37
          }

          logger.formatter = proc do |severity, datetime, progname, message|
            displayed_message = "[#{datetime.to_s}] Forest 🌳🌳🌳  " \
                  "#{message}\n"
                "\e[#{logger_colors[severity.to_sym]}m#{displayed_message}\033[0m"
          end
          logger
        end
      end
    end
  end

  class Reporter
    def self.report (error)
      ForestLiana.reporter.report error if ForestLiana.reporter
    end
  end
end

FOREST_LOGGER = ForestLiana::Logger.log
FOREST_REPORTER = ForestLiana::Reporter
