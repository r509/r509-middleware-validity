require "redis"
require "r509/Validity/Redis/Writer"

module R509
    module Middleware
        class Validity
            def initialize(app)
                @app = app

                redis = Redis.new
                @app.log.info redis.inspect
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
                elsif not (env["PATH_INFO"] =~ /^\/1\/certificate\/revoke\/?$/).nil? and status == 200
                    begin
                        params = parse_params(env)

                        serial = params["serial"]
                        reason = params["reason"].to_i || 0

                        @app.log.info "Revoking serial: #{serial}, reason: #{reason}"

                        @writer.revoke(serial, Time.now.to_i, reason)
                    rescue
                        @app.log.info "Failed to revoke"
                    end
                elsif not (env["PATH_INFO"] =~ /^\/1\/certificate\/unrevoke\/?$/).nil? and status == 200
                    begin
                        params = parse_params(env)

                        serial = params["serial"]

                        @app.log.info "Unrevoking serial: #{serial}"

                        @writer.unrevoke(serial)
                    rescue
                    end
                end

                [status, headers, response]
            end

            private

            def parse_params(env)
                raw_request = env["rack.input"].read
                env["rack.input"].rewind

                Rack::Utils.parse_query(raw_request)
            end
        end
    end
end
