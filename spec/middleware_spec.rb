require "#{File.dirname(__FILE__)}/spec_helper"
require "sinatra"
require "logger"

class TestServer < Sinatra::Base
    configure do
        set :log, Logger.new(nil)
        set :certificate_authorities, nil
    end

    error StandardError do
        env["sinatra.error"].message
    end

    get "/some/path/?" do
        "return value"
    end

    post "/1/certificate/issue/?" do
        if params["successful"]
            TestFixtures::CERT
        elsif params["invalid_body"]
            "invalid cert body"
        else
            raise StandardError.new("Error")
        end
    end

    post "/1/certificate/revoke/?" do
        if params["successful"]
            "CRL"
        else
            raise StandardError.new("Error")
        end
    end

    post "/1/certificate/unrevoke/?" do
        if params["successful"]
            "CRL"
        else
            raise StandardError.new("Error")
        end
    end
end

describe R509::Middleware::Validity do
    before :each do
        @logger = double("logger")
        @redis = double("redis")
        @config = double("config")
        @ca_cert = double("ca_cert")
        @certificate_authorities = double("certificate_authorities")

        verbosity = $VERBOSE
        $VERBOSE = nil
        R509::Validity::Redis::Writer = double("writer")
        $VERBOSE = verbosity

        R509::Validity::Redis::Writer.should_receive(:new).with(@redis).and_return(R509::Validity::Redis::Writer)
    end
    def app
        test_server = TestServer
        test_server.send(:set, :log, @logger)
        test_server.send(:set, :certificate_authorities, @certificate_authorities)

        @app ||= R509::Middleware::Validity.new(test_server,@redis)
    end

    context "some path" do
        it "returns some return value" do
            get "/some/path"
            last_response.body.should == "return value"
        end
    end

    context "issuing" do
        it "intercepts issuance" do
            R509::Validity::Redis::Writer.should_receive(:issue).with("/C=US/O=SecureTrust Corporation/CN=SecureTrust CA","211653423715")
            @logger.should_receive(:info).with("Writing serial: 211653423715")

            post "/1/certificate/issue", :successful => true
            last_response.status.should == 200
            last_response.body.should == TestFixtures::CERT
        end
        it "fails issuance" do
            post "/1/certificate/issue/"
            last_response.status.should == 500
        end
        it "invalid cert body" do
            @logger.should_receive(:error).exactly(3).times
            post "/1/certificate/issue", :invalid_body => true
            last_response.status.should == 200
            last_response.body.should == "invalid cert body"
        end
    end

    context "revoking" do
        it "intercepts revoke" do
            R509::Validity::Redis::Writer.should_receive(:revoke).with("/CN=Some CA","1234", Time.now.to_i, 0)
            @logger.should_receive(:info).with("Revoking serial: 1234, reason: 0")
            @certificate_authorities.should_receive(:[]).with("some_ca").and_return(@config)
            @config.should_receive(:ca_cert).and_return(@ca_cert)
            @ca_cert.should_receive(:subject).and_return("/CN=Some CA")

            post "/1/certificate/revoke", :successful => true, :serial => 1234, :ca => "some_ca"
            last_response.status.should == 200
        end
        it "intercepts revoke with reason" do
            R509::Validity::Redis::Writer.should_receive(:revoke).with("/CN=Some CA","1234", Time.now.to_i, 1)
            @logger.should_receive(:info).with("Revoking serial: 1234, reason: 1")
            @certificate_authorities.should_receive(:[]).with("some_ca").and_return(@config)
            @config.should_receive(:ca_cert).and_return(@ca_cert)
            @ca_cert.should_receive(:subject).and_return("/CN=Some CA")
            post "/1/certificate/revoke", :successful => true, :ca => "some_ca", :serial => 1234, :reason => 1
            last_response.status.should == 200
        end
        it "fails to revoke" do
            post "/1/certificate/revoke"
            last_response.status.should == 500
        end
    end

    context "unrevoking" do
        it "intercepts unrevoke" do
            R509::Validity::Redis::Writer.should_receive(:unrevoke).with("/CN=Some CA","1234")
            @logger.should_receive(:info).with("Unrevoking serial: 1234")
            @certificate_authorities.should_receive(:[]).with("some_ca").and_return(@config)
            @config.should_receive(:ca_cert).and_return(@ca_cert)
            @ca_cert.should_receive(:subject).and_return("/CN=Some CA")
            post "/1/certificate/unrevoke", :successful => true, :serial => 1234, :ca => "some_ca"
            last_response.status.should == 200
        end
        it "fails to record unrevoke" do
            R509::Validity::Redis::Writer.should_receive(:unrevoke).with("/CN=Some CA","1234").and_raise(StandardError)
            @logger.should_receive(:info).with("Unrevoking serial: 1234")
            @logger.should_receive(:error).exactly(3).times
            @certificate_authorities.should_receive(:[]).with("some_ca").and_return(@config)
            @config.should_receive(:ca_cert).and_return(@ca_cert)
            @ca_cert.should_receive(:subject).and_return("/CN=Some CA")
            post "/1/certificate/unrevoke", :successful => true, :serial => 1234, :ca => "some_ca"
            last_response.status.should == 200
        end
        it "fails to unrevoke" do
            post "/1/certificate/unrevoke"
            last_response.status.should == 500
        end
    end
end
