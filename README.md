This project is related to [r509](http://github.com/reaperhulk/r509) and [r509-ca-http](http://github.com/sirsean/r509-ca-http), allowing us to save certificate validity status to a Redis backend via Rack Middleware, so the CA itself doesn't need to know anything about Redis. This is done so that you can run a CA without saving validity status, if you want to do that.

If you want to use it, plug it into your config.ru, similar to this:

    require './lib/r509/CertificateAuthority/Http/Server'
    require 'r509/Middleware/Validity'

    use R509::Middleware::Validity
    run R509::CertificateAuthority::Http::Server
