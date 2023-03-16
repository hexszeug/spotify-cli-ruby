# frozen_string_literal: true

require 'test/unit'
require './lib/spotify'

class RequestTest < Test::Unit::TestCase
  def test_http_request
    calls = 0
    server = TCPServer.new(8888)
    Spotify::Request.http(
      'http://localhost:8888/path/?q=query',
      :post,
      { header: 'my_header' },
      'my_body'
    ) do |res|
      calls += 1
      assert_equal('200', res.code)
      assert_equal('my_body', res.body)
    end

    assert_equal(0, calls)

    socket = server.accept
    req_line = socket.gets
    req_header = ''
    while (line = socket.gets) != "\r\n"
      req_header += line
    end
    req_body = ''
    7.times { req_body += socket.getc }

    assert_equal(0, calls)
    assert_match(
      %r{^POST /path/\?q=query HTTP/\d\.\d\r$},
      req_line
    )
    assert_match(/^Header: my_header\r$/, req_header)
    assert_equal('my_body', req_body)

    socket.print("HTTP/1.0 200 OK\r\n\r\nmy_body")
    socket.close
    server.close

    sleep 0.1
    assert_equal(1, calls)
  end
end
