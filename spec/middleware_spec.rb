require "#{File.dirname(__FILE__)}/spec_helper"
require "sinatra"
require "logger"

class TestServer < Sinatra::Base
    configure do
        set :log, Logger.new(nil)
    end

    helpers do
        def log
            settings.log
        end
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
    def app
        @app ||= R509::Middleware::Validity.new(TestServer)
    end

    context "some path" do
        class R509::Validity::Redis::Writer
            def issue(serial)
                raise StandardError.new("Should never issue")
            end
            def revoke(serial, reason=0)
                raise StandardError.new("Should never revoke")
            end
            def unrevoke(serial)
                raise StandardError.new("Should never unrevoke")
            end
        end
        it "returns some return value" do
            get "/some/path"
            last_response.body.should == "return value"
        end
    end

    context "issuing" do
        it "intercepts issuance" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Must issue serial 211653423715") unless serial == "211653423715"
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/issue", :successful => true
            last_response.status.should == 200
            last_response.body.should == TestFixtures::CERT
        end
        it "fails issuance" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/issue/"
            last_response.status.should == 500
        end
        it "invalid cert body" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/issue", :invalid_body => true
            last_response.status.should == 200
            last_response.body.should == "invalid cert body"
        end
    end

    context "revoking" do
        it "intercepts revoke" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Must revoke 1234 (not #{serial})") unless serial == 1234.to_s and reason == 0
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/revoke", :successful => true, :serial => 1234
            last_response.status.should == 200
        end
        it "intercepts revoke with reason" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Must revoke 1234 (not #{serial})") unless serial == 1234.to_s and reason == 1
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/revoke", :successful => true, :serial => 1234, :reason => 1
            last_response.status.should == 200
        end
        it "fails to revoke" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/revoke"
            last_response.status.should == 500
        end
    end

    context "unrevoking" do
        it "intercepts unrevoke" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Should unrevoke 1234, not #{serial}") unless serial == 1234.to_s
                end
            end
            post "/1/certificate/unrevoke", :successful => true, :serial => 1234
            last_response.status.should == 200
        end
        it "fails to record unrevoke" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Unrevoke failed, probably because the cert didn't exist")
                end
            end
            post "/1/certificate/unrevoke", :successful => true, :serial => 1234
            last_response.status.should == 200
        end
        it "fails to unrevoke" do
            class R509::Validity::Redis::Writer
                def issue(serial)
                    raise StandardError.new("Should never issue")
                end
                def revoke(serial, reason=0)
                    raise StandardError.new("Should never revoke")
                end
                def unrevoke(serial)
                    raise StandardError.new("Should never unrevoke")
                end
            end
            post "/1/certificate/unrevoke"
            last_response.status.should == 500
        end
    end
end
