require "redis"
require "r509/Validity/Redis/Writer"

module R509
    module Middleware
        class Validity
            def initialize(app,redis=nil)
                @app = app

                if redis.nil?
                    redis = Redis.new
                end
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
                        @app.log.info "Writing serial: #{cert.serial.to_s}"
                        @writer.issue(cert.issuer.to_s,cert.serial.to_s)
                    rescue => e
                        @app.log.error "Writing failed"
                        @app.log.error e.inspect
                        @app.log.error e.backtrace.join("\n")
                    end
                elsif not (env["PATH_INFO"] =~ /^\/1\/certificate\/revoke\/?$/).nil? and status == 200
                    begin
                        params = parse_params(env)

                        issuer = @app.certificate_authorities[params["ca"]].ca_cert.subject.to_s
                        serial = params["serial"]
                        reason = params["reason"].to_i || 0

                        @app.log.info "Revoking serial: #{serial}, reason: #{reason}"

                        @writer.revoke(issuer, serial, Time.now.to_i, reason)
                    rescue => e
                        @app.log.error "Revoking failed: #{serial}"
                        @app.log.error e.inspect
                        @app.log.error e.backtrace.join("\n")
                    end
                elsif not (env["PATH_INFO"] =~ /^\/1\/certificate\/unrevoke\/?$/).nil? and status == 200
                    begin
                        params = parse_params(env)

                        issuer = @app.certificate_authorities[params["ca"]].ca_cert.subject.to_s
                        serial = params["serial"]

                        @app.log.info "Unrevoking serial: #{serial}"

                        @writer.unrevoke(issuer, serial)
                    rescue => e
                        @app.log.error "Unrevoking failed: #{serial}"
                        @app.log.error e.inspect
                        @app.log.error e.backtrace.join("\n")
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
