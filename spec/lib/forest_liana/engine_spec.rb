require 'rake'

module ForestLiana
  describe Engine do
    subject(:engine) { ForestLiana::Engine.instance }

    describe '#rake?' do
      around do |example|
        original_program_name = $0
        example.run
        $0 = original_program_name
      end

      context 'when invoked through the legacy `rake` binary' do
        it 'returns true' do
          $0 = '/usr/local/bin/rake'

          expect(engine.rake?).to be(true)
        end
      end

      context 'when invoked through `rails` while running a Rake task (e.g. rails db:migrate)' do
        it 'returns true so the bootstrapper does not introspect models mid-task' do
          $0 = '/usr/local/bin/rails'
          allow(Rake.application).to receive(:top_level_tasks).and_return(['db:migrate'])

          expect(engine.rake?).to be(true)
        end
      end

      context 'when booting the application to serve (rails server / console)' do
        it 'returns false so the bootstrapper runs and builds the apimap' do
          $0 = '/usr/local/bin/rails'
          allow(Rake.application).to receive(:top_level_tasks).and_return([])

          expect(engine.rake?).to be(false)
        end
      end

      context 'when only the default Rake task is present' do
        it 'returns false' do
          $0 = '/usr/local/bin/rails'
          allow(Rake.application).to receive(:top_level_tasks).and_return(['default'])

          expect(engine.rake?).to be(false)
        end
      end

      context 'when Rake is only partially loaded (Rake constant defined without Rake.application)' do
        # Reproduces the boot crash: Rails' test_unit integration requires
        # `rake/file_list`, which defines the Rake module without loading
        # rake/application. `defined?(Rake)` is then truthy but `Rake.application`
        # is undefined, so the old guard raised NoMethodError at boot.
        it 'returns false instead of raising NoMethodError' do
          $0 = '/usr/local/bin/rails'
          allow(Rake).to receive(:respond_to?).and_call_original
          allow(Rake).to receive(:respond_to?).with(:application).and_return(false)
          allow(Rake).to receive(:application).and_raise(
            NoMethodError.new("undefined method 'application' for module Rake")
          )

          expect { engine.rake? }.not_to raise_error
          expect(engine.rake?).to be(false)
        end
      end
    end
  end
end
