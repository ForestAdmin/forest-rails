require 'ipaddress'

module ForestLiana
  class IpWhitelistChecker
    module RuleType
      IP = 0
      RANGE = 1
      SUBNET = 2
    end

    def self.is_ip_matches_any_rule(ip, rules)
      rules.any? { |rule| IpWhitelistChecker.is_ip_matches_rule(ip, rule) }
    end

    def self.is_ip_matches_rule(ip, rule)
      if rule['type'] == RuleType::IP
        return IpWhitelistChecker.is_ip_match_ip(ip, rule['ip'])
      elsif rule['type'] == RuleType::RANGE
        return IpWhitelistChecker.is_ip_match_range(ip, rule)
      elsif rule['type'] == RuleType::SUBNET
        return IpWhitelistChecker.is_ip_match_subnet(ip, rule['range'])
      end

      raise 'Invalid rule type'
    end

    def self.ip_version(ip)
      (IPAddress ip).is_a?(IPAddress::IPv4) ? :ip_v4 : :ip_v6
    end

    def self.is_same_ip_version(ip1, ip2)
      ip1_version = IpWhitelistChecker.ip_version(ip1)
      ip2_version = IpWhitelistChecker.ip_version(ip2)

      ip1_version == ip2_version
    end

    def self.is_both_loopback(ip1, ip2)
      IPAddress(ip1).loopback? && IPAddress(ip2).loopback?
    end

    def self.is_ip_match_ip(ip1, ip2)
      if !IpWhitelistChecker.is_same_ip_version(ip1, ip2)
        return IpWhitelistChecker.is_both_loopback(ip1, ip2)
      end

      if IPAddress(ip1) == IPAddress(ip2)
        true
      else
        IpWhitelistChecker.is_both_loopback(ip1, ip2)
      end
    end

    def self.is_ip_match_range(ip, rule)
      return false if !IpWhitelistChecker.is_same_ip_version(ip, rule['ip_minimum'])

      ip_range_minimum = (IPAddress rule['ip_minimum']).to_i
      ip_range_maximum = (IPAddress rule['ip_maximum']).to_i
      ip_value = (IPAddress ip).to_i

      return ip_value >= ip_range_minimum && ip_value <= ip_range_maximum
    end

    def self.is_ip_match_subnet(ip, subnet)
      return false if !IpWhitelistChecker.is_same_ip_version(ip, subnet)

      IPAddress(subnet).include?(IPAddress(ip))
    end
  end

end
