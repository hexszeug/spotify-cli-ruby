require 'net/http'

API = 'https://api.spotify.com/v1/'

def get path, query, header
    path = API + path unless path =~ /^https?:\/\//
    uri = URI(path + URI.encode_www_form(query))
    req = Net::HTTP::Get.new uri
    header.each {|key, value| req[key] = value}
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') {|http|
        http.request(req)
    }
    unless res.class < Net::HTTPSuccess
        raise res.code #TODO
    end
    return res
end

def post path, query, header, body
    path = API + path unless path =~ /^https?:\/\//
    uri = URI(path + URI.encode_www_form(query))
    body = URI.encode_www_form(body) #TODO
    req = Net::HTTP::Post.new uri
    header.each {|key, value| req[key] = value}
    req.body = body

    puts req.uri
    req.each {|k, v| puts "#{k}: #{v}"}

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') {|http|
        http.request(req)
    }

    puts
    puts res.code + ' ' + res.class.to_s.match(/^Net::HTTP(.*)$/)[1]
    res.each {|k, v| puts "#{k}: #{v}"}

    unless res.class < Net::HTTPSuccess
        raise res.code #TODO
    end
    return res
end