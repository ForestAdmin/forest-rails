module ForestLiana
  describe Logger do
    describe 'self.log' do
      describe 'with a logger overload' do
        it 'should return the given logger' do
          logger = ActiveSupport::Logger.new($stdout)
          logger.formatter = proc do |severity, datetime, progname, msg|
            {:message => msg}.to_json
          end
          ForestLiana.logger = logger

          expect(Logger.log.is_a?(ActiveSupport::Logger)).to be_truthy
          expect { Logger.log.error "[error] override logger" }.to output({:message => "[error] override logger"}.to_json).to_stdout_from_any_process
          expect { Logger.log.info "[info] override logger" }.to output({:message => "[info] override logger"}.to_json).to_stdout_from_any_process
        end
      end

      describe 'with no logger overload' do
        it 'should return an instance of ::Logger' do
          ForestLiana.logger = nil

          expect(Logger.log.is_a?(::Logger)).to be_truthy
          # RegExp is used to check for the forestadmin logger format
          expect { Logger.log.error "[error] default logger" }.to output(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] Forest .* \[error\]/).to_stdout_from_any_process
          expect { Logger.log.info "[info] default logger" }.to output(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] Forest .* \[info\]/).to_stdout_from_any_process
        end
      end
    end
  end
end
