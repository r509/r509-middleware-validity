require "redis"
require "dependo"
require "r509/validity/redis/writer"

module R509
    module Middleware
        class Validity
            include Dependo::Mixin

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
                        log.info "Writing serial: #{cert.serial.to_s}, Issuer: #{cert.issuer.to_s}"
                        @writer.issue(cert.issuer.to_s,cert.serial.to_s)
                    rescue => e
                        log.error "Writing failed"
                        log.error e.inspect
                    end
                elsif not (env["PATH_INFO"] =~ /^\/1\/certificate\/revoke\/?$/).nil? and status == 200
                    begin
                        params = parse_params(env)

                        issuer = @app.config_pool[params["ca"]].ca_cert.subject.to_s
                        serial = params["serial"]
                        reason = params["reason"].to_i || 0

                        log.info "Revoking serial: #{serial}, reason: #{reason}"

                        @writer.revoke(issuer, serial, Time.now.to_i, reason)
                    rescue => e
                        log.error "Revoking failed: #{serial}"
                        log.error e.inspect
                    end
                elsif not (env["PATH_INFO"] =~ /^\/1\/certificate\/unrevoke\/?$/).nil? and status == 200
                    begin
                        params = parse_params(env)

                        issuer = @app.config_pool[params["ca"]].ca_cert.subject.to_s
                        serial = params["serial"]

                        log.info "Unrevoking serial: #{serial}"

                        @writer.unrevoke(issuer, serial)
                    rescue => e
                        log.error "Unrevoking failed: #{serial}"
                        log.error e.inspect
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
