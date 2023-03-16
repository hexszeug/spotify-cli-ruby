# frozen_string_literal: true

require './lib/spotify'
require 'test/unit'

class CodeServerTest < Test::Unit::TestCase
  include Spotify::Auth::CodeServer

  class << Spotify::Auth::CodeServer
    attr_accessor :state, :callback, :server
  end

  def request(str)
    Socket.tcp('localhost', 8888) do |socket|
      socket.print(str)
      socket.close_write
      return socket.read
    end
  end

  def teardown
    Spotify::Auth::CodeServer.stop
  end

  def test_all_no_error
    calls = 0
    assert_nothing_raised do
      Spotify::Auth::CodeServer.start('my_state') do |code|
        calls += 1
        assert_equal('my_code', code)
      end
    end
    assert_equal(0, calls)
    assert_match(
      /200 OK/,
      request("GET /callback/?code=my_code&state=my_state HTTP/1.0\r\n\r\n")
    )
    assert_equal(1, calls)
    assert_nil Spotify::Auth::CodeServer.server
  end

  def test_open_error
    server = TCPServer.new 'localhost', 8888
    calls = 0
    assert_raise(Spotify::Auth::CodeServer::OpenServerError) do
      Spotify::Auth::CodeServer.start('my_state') { calls += 1 }
    end
    assert_equal 0, calls
    server.close
  end

  def test_wrong_path
    calls = 0
    Spotify::Auth::CodeServer.start('my_state') { calls += 1 }
    assert_equal 0, calls
    assert_match(/204 No Content/, request("GET / HTTP/1.0\r\n\r\n"))
    assert_match(/204 No Content/, request("GET /random/path HTTP/1.0\r\n\r\n"))
    Spotify::Auth::CodeServer.state = nil
    assert_match(
      /204 No Content/,
      request("GET /callback/?state=my_state&code=my_code HTTP/1.0\r\n\r\n")
    )
    assert_equal 0, calls
  end

  def test_bad_request
    calls = 0
    Spotify::Auth::CodeServer.start('my_state') { calls += 1 }
    assert_equal 0, calls
    assert_match(/400 Bad Request/, request('not an http request'))
    assert_match(
      /400 Bad Request/,
      request("GET /callback/?code=my_code HTTP/1.0\r\n\r\n")
    )
    assert_match(
      /400 Bad Request/,
      request("GET /callback/?state=wrong_state&code=my_code HTTP/1.0\r\n\r\n")
    )
    assert_equal 0, calls
  end

  def test_code_denied
    calls = 0
    Spotify::Auth::CodeServer.start('my_state') do |code|
      calls += 1
      assert_instance_of Spotify::Auth::CodeServer::CodeDeniedError, code
      assert_equal code.error_str, 'my_error'
    end
    assert_equal 0, calls
    assert_match(
      /400 Bad Request/,
      request("GET /callback/?state=my_state&error=my_error HTTP/1.0\r\n\r\n")
    )
    assert_equal 1, calls
    assert_nil Spotify::Auth::CodeServer.server
  end

  def test_internal_server_error
    calls = 0
    Spotify::Auth::CodeServer.start('my_state') do |code|
      calls += 1
      raise 'my_error' unless code.is_a? StandardError

      assert_equal('my_error', code.message)
    end
    assert_equal 0, calls
    assert_match(
      /500 Internal Server Error/,
      request("GET /callback/?state=my_state&code=my_code HTTP/1.0\r\n\r\n")
    )
    assert_equal 2, calls
    assert_nil Spotify::Auth::CodeServer.server
  end
end
