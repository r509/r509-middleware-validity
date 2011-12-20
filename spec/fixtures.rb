require 'spec_helper'
require 'pathname'
require 'r509/io_helpers'

module TestFixtures
    extend R509::IOHelpers

    FIXTURES_PATH = Pathname.new(__FILE__).dirname + "fixtures"

    def self.read_fixture(filename)
        read_data((FIXTURES_PATH + filename).to_s)
    end

    #Trustwave cert for langui.sh
    CERT = read_fixture('cert1.pem')
end
