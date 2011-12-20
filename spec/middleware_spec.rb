require "#{File.dirname(__FILE__)}/spec_helper"
require "sinatra"

class TestServer < Sinatra::Base
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
            end
            post "/1/certificate/issue", :invalid_body => true
            last_response.status.should == 200
            last_response.body.should == "invalid cert body"
        end
    end
end
