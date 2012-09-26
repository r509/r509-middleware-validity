# r509-middleware-validity

This project is related to [r509](http://github.com/reaperhulk/r509) and [r509-ca-http](http://github.com/sirsean/r509-ca-http), allowing us to save certificate validity status to a Redis backend via Rack Middleware, so the CA itself doesn't need to know anything about Redis. This is done so that you can run a CA without saving validity status, if you want to do that.

# Redis

Make sure you have a Redis server running on localhost. The standard configuration should work. You also need to ```gem install redis```.

Ruby will connect to it using ```Redis.new```.

# config.ru

    require 'r509/middleware/validity'

    use R509::Middleware::Validity
    run R509::CertificateAuthority::Http::Server

Now all the issue/revoke/unrevoke events will be saved in your Redis database.
