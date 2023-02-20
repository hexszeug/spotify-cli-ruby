require 'net/http'
require 'json'

module Request
    def Request.get(path, query: {}, header: {})
        request Net::HTTP::Get, path, query, header
    end

    def Request.post(path, query: {}, header: {}, body: '')
        request Net::HTTP::Post, path, query, header, body
    end

    def Request.put(path, query: {}, header: {}, body: '')
        request Net::HTTP::Put, path, query, header, body
    end

    def Request.delete(path, query: {}, header: {}, body: '')
        request Net::HTTP::Delete, path, query, header, body
    end

    private_class_method def Request.request(
        http_req_class,
        path,
        query,
        header,
        body = ''
    )
        uri = URI(path + URI.encode_www_form(query))
        body = URI.encode_www_form(body) unless body.kind_of? String

        req = http_req_class.new uri
        header.each { |key, value| req[key] = value }
        req.body = body if http_req_class::REQUEST_HAS_BODY

        puts req.uri #TODO better debug messages
        req.each { |k, v| puts "#{k}: #{v}" } #

        res =
            Net::HTTP.start(
                uri.hostname,
                uri.port,
                use_ssl: uri.scheme == 'https'
            ) { |http| http.request(req) }

        puts #
        puts res.code + ' ' + res.class.to_s.match(/^Net::HTTP(.*)$/)[1] #TODO better debug messages
        res.each { |k, v| puts "#{k}: #{v}" } #

        return res
    end
end

module Spotify
    def Spotify.get_current_users_profile(account:)
        JSON[(api_call :GET, '/me', account: account).body, symbolize_names: true]
        #TODO error handling
    end

    def Spotify.skip_to_next(account:, device: nil)
        query = device && device[:id] ? { device_id: device[:id] } : {}
        api_call :POST, '/me/player/next', account: account, query: query
        #TODO error handling
    end

    def Spotify.skip_to_previous(account:, device: nil)
        query = device && device[:id] ? { device_id: device[:id] } : {}
        api_call :POST, '/me/player/previous', account: account, query: query
        #TODO error handling
    end

    private_class_method def Spotify.api_call(
        method,
        endpoint,
        account:,
        query: {},
        body: {}
    )
        endpoint.gsub! %r{^/|/$}, '' # remove leading and trailing slashes
        path = "https://api.spotify.com/v1/#{endpoint}/"
        header = account.authorize({ 'content-type': 'application/json' })
        body = JSON[body]
        case method
        when :GET
            Request.get path, query: query, header: header
        when :POST
            Request.post path, query: query, header: header, body: body
        when :PUT
            Request.put path, query: query, header: header, body: body
        when :DELETE
            Request.put path, query: query, header: header, body: body
        end
        #TODO handle errors
    end
end
