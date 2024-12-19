module ForestLiana
  describe Errors do
    describe 'ExpectedError' do
      describe 'when initializing' do
        describe 'when backtrace is added' do
          it 'should add the backtrace to the errors if passed' do
            err = nil

            begin
              raise "This is an exception"
            rescue => error
              err = ForestLiana::Errors::ExpectedError.new(300, 300, error.message, nil, error.backtrace )
            end

            expect(err.backtrace).to be_truthy
          end
        end
        describe 'when backtrace is not added' do
          it 'should not break nor add any backtrace' do
            err = nil

            begin
              raise "This is an exception"
            rescue => error
              err = ForestLiana::Errors::ExpectedError.new(300, 300, error.message, nil)
            end

            expect(err.backtrace).to be_falsy
          end
        end
      end
    end
  end
end