require "helper"
require 'spore/spec_parser/yaml'

class TestTestSelfSignedCertificate < Test::Unit::TestCase
  def test_no_verify_ssl_cert
    yaml = File.expand_path( '../royce.yml', __FILE__)
    assert_raise OpenSSL::SSL::SSLError do
      spore = Spore.new(yaml)
      spore.get_repos(:id => 1, :account_id => 1, :format => :json)
    end
    assert_nothing_raised do
      spore = Spore.new(yaml, :client_config => {:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE })
      spore.get_repos(:id => 1, :account_id => 1, :format => :json)
    end
  end
end
