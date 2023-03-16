# frozen_string_literal: true

require 'test/unit'
require './lib/spotify'

require 'launchy'

class PromptTest < Test::Unit::TestCase
  class << self
    attr_accessor :arg, :raises
  end

  def Launchy.open(arg)
    raise Launchy::Error if PromptTest.raises

    PromptTest.arg = arg
  end

  def setup
    PromptTest.arg = nil
    PromptTest.raises = false
  end

  def test_open
    Spotify::Auth::Prompt.open('my_state')
    assert_not_nil(PromptTest.arg)
    assert_match(%r{https://accounts.spotify.com/authorize/}, PromptTest.arg)
    assert_match(/state=my_state/, PromptTest.arg)
  end

  def test_broken
    PromptTest.raises = true
    assert_raise(Spotify::Auth::Prompt::OpenPromptError) do
      Spotify::Auth::Prompt.open('my_state')
    end
  end
end
