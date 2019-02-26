module ForestLiana
  describe IpWhitelistChecker do
    describe 'Check is_ip_matches_rule function' do
      describe 'with IP "90.88.0.1" and "90.88.0.2"' do
        it 'should return false' do
          rule = {
            'type' => 0,
            'ip' => '90.88.0.1',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.0.2', rule)

          expect(is_matching).to eq(false)
        end
      end

      describe 'with IP "::1" and "aaaa"' do
        it 'should raise an "ArgumentError" exception with "Unknown IP Address aaaa" message' do
          rule = {
            'type' => 0,
            'ip' => '::1',
          }

          expect {
            IpWhitelistChecker.is_ip_matches_rule('aaaa', rule)
          }.to raise_error(ArgumentError, 'Unknown IP Address aaaa')
        end
      end

      describe 'with IP "90.88.0.1" and "::1"' do
        it 'should return false' do
          rule = {
            'type' => 0,
            'ip' => '90.88.0.1',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('::1', rule)

          expect(is_matching).to eq(false)
        end
      end

      describe 'with IP "::1" and "::1"' do
        it 'should return true' do
          rule = {
            'type' => 0,
            'ip' => '::1',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('::1', rule)

          expect(is_matching).to eq(true)
        end
      end

      describe 'with IP "90.88.0.1" and "90.88.0.1"' do
        it 'should return true' do
          rule = {
            'type' => 0,
            'ip' => '90.88.0.1',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.0.1', rule)

          expect(is_matching).to eq(true)
        end
      end

      describe 'with IP "90.88.0.0" and "90.88.0.0"' do
        it 'should return true' do
          rule = {
            'type' => 0,
            'ip' => '90.88.0.0',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.0.0', rule)

          expect(is_matching).to eq(true)
        end
      end

      describe 'with IP "127.0.0.1" and "::1"' do
        it 'should return true' do
          rule = {
            'type' => 0,
            'ip' => '127.0.0.1',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('::1', rule)

          expect(is_matching).to eq(true)
        end
      end

      describe 'with range "90.88.0.0 - 90.88.255.255' do
        rule = {
          'type' => 1,
          'ip_minimum' => '90.88.0.0',
          'ip_maximum' => '90.88.255.255',
        }

        describe 'with IP "90.89.0.1"' do
          it 'should return false' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('90.89.0.1', rule)

            expect(is_matching).to eq(false)
          end
        end

        describe 'with IP "::ffff:90.89.0.1"' do
          it 'should return false' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('::ffff:90.89.0.1', rule)

            expect(is_matching).to eq(false)
          end
        end

        describe 'with IP "90.88.118.79"' do
          it 'should return false' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.118.79', rule)

            expect(is_matching).to eq(true)
          end
        end
      end

      describe 'with range "90.88.0.1 - 90.88.255.255" and IP "90.88.118.79"' do
        it 'should return true' do
          rule = {
            'type' => 1,
            'ip_minimum' => '90.88.0.1',
            'ip_maximum' => '90.88.255.255',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.118.79', rule)

          expect(is_matching).to eq(true)
        end
      end

      describe 'with range "90.88.0.1 - 90.88.254.254" and IP "90.88.118.79"' do
        it 'should return true' do
          rule = {
            'type' => 1,
            'ip_minimum' => '90.88.0.1',
            'ip_maximum' => '90.88.254.254',
          }

          is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.118.79', rule)

          expect(is_matching).to eq(true)
        end
      end

      describe 'with subnet "90.88.0.0/24"' do
        rule = {
          'type' => 2,
          'range' => '90.88.0.0/24',
        }

        describe 'with IP "90.88.0.1"' do
          it 'should return true' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.0.1', rule)

            expect(is_matching).to eq(true)
          end
        end

        describe 'with IP "90.88.0.0"' do
          it 'should return true' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.0.0', rule)

            expect(is_matching).to eq(true)
          end
        end

        describe 'with IP "90.88.0.254"' do
          it 'should return true' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.0.254', rule)

            expect(is_matching).to eq(true)
          end
        end

        describe 'with IP "90.88.1.1"' do
          it 'should return true' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('90.88.1.1', rule)

            expect(is_matching).to eq(false)
          end
        end

        describe 'with IP "::1"' do
          it 'should return true' do
            is_matching = IpWhitelistChecker.is_ip_matches_rule('::1', rule)

            expect(is_matching).to eq(false)
          end
        end
      end
    end
  end
end
