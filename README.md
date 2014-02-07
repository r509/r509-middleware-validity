# r509-middleware-validity [![Build Status](https://secure.travis-ci.org/r509/r509-middleware-validity.png)](http://travis-ci.org/r509/r509-middleware-validity) [![Coverage Status](https://coveralls.io/repos/r509/r509-middleware-validity/badge.png?branch=master)](https://coveralls.io/r/r509/r509-middleware-validity?branch=master)

This project is related to [r509](http://github.com/r509/r509) and [r509-ca-http](http://github.com/r509/r509-ca-http), allowing us to save certificate validity status to a Redis backend via Rack Middleware, so the CA itself doesn't need to know anything about Redis. This is done so that you can run a CA without saving validity status, if you want to do that.

# Redis

Make sure you have a Redis server running on localhost. The standard configuration should work. You also need to ```gem install redis```.

Ruby will connect to it using ```Redis.new```.

# config.ru

    require 'r509/middleware/validity'

    use R509::Middleware::Validity
    run R509::CertificateAuthority::Http::Server

Now all the issue/revoke/unrevoke events will be saved in your Redis database.
