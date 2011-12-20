require "r509"
require "redis"
require "r509/Validity/Redis/Writer"

module R509
    module Middleware
        class Validity
            def initialize(app)
                @app = app

                redis = Redis.new
                @writer = R509::Validity::Redis::Writer.new(redis)
            end

            def call(env)
                status, headers, response = @app.call(env)

                # we only want to attempt to record validity if status is 200 and it's a call
                # to the "/1/certificate/issue" path
                if not (env["PATH_INFO"] =~ /^\/1\/certificate\/issue\/?$/).nil? and status == 200
                    body = ""
                    response.each do |part|
                        body += part
                    end
                    begin
                        cert = R509::Cert.new(:cert => body)
                        @app.log.info "Recording serial: #{cert.cert.serial.to_s}"
                        @writer.issue(cert.cert.serial.to_s)
                    rescue
                    end
                end

                [status, headers, response]
            end
        end
    end
end
