module ForestLiana
  describe ForestApiRequester do
    describe 'when an error occurs' do
      before do
        allow(HTTParty).to receive(:get).and_raise(StandardError, 'Custom error message')
        allow(HTTParty).to receive(:post).and_raise(StandardError, 'Custom error message')
      end

      describe 'Get' do
        it 'should keep the original error and raise it with backtrace' do
          err = nil

          begin
            ForestApiRequester.get('/incorrect_url')
          rescue => error
            err = error
          end

          expect(error)
            .to be_instance_of(StandardError)
            .and have_attributes(:message => 'Custom error message')
            .and have_attributes(:backtrace => be_truthy)
        end
      end

      describe 'Post' do
        it 'should keep the original error and raise it with backtrace' do
          err = nil

          begin
            ForestApiRequester.post('/incorrect_url')
          rescue => error
            err = error
          end

          expect(error)
            .to be_instance_of(StandardError)
            .and have_attributes(:message => 'Custom error message')
            .and have_attributes(:backtrace => be_truthy)
        end
      end
    end
  end
end
