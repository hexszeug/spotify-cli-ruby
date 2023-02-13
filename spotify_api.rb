require 'net/http'

module Request
    API = 'https://api.spotify.com/v1/'

    def Request.get path, query, header
        request Net::HTTP::Get, path, query, header
    end

    def Request.post path, query, header, body
        request Net::HTTP::Post, path, query, header, body
    end

    def Request.put path, query, header, body
        request Net::HTTP::Put, path, query, header, body
    end

    def Request.delete path, query, header
        request Net::HTTP::Delete, path, query, header
    end

    private_class_method def Request.request http_req_class, path, query, header, body={}, debug=false
        path = API + path unless path =~ /^https?:\/\//
        uri = URI(path + URI.encode_www_form(query))
        body = URI.encode_www_form(body) #TODO

        req = http_req_class.new uri
        header.each {|key, value| req[key] = value}
        req.body = body if http_req_class::REQUEST_HAS_BODY

        puts req.uri #TODO better debug messages (including using debug param)
        req.each {|k, v| puts "#{k}: #{v}"}

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') {|http|
            http.request(req)
        }

        puts
        puts res.code + ' ' + res.class.to_s.match(/^Net::HTTP(.*)$/)[1]
        res.each {|k, v| puts "#{k}: #{v}"}

        unless res.class < Net::HTTPSuccess
            raise res.code #TODO better error handling
        end
        res
    end
end