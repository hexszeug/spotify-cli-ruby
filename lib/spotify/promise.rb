# frozen_string_literal: true

module Spotify
  class Promise
    attr_reader :resolved, :canceled, :failed

    def initialize(&)
      callback(&)
      @resolved = false
      @canceled = false
      @failed = false
    end

    # supposed to be called by the receiver
    def callback(&block)
      @callback = block
      resolve(*@args) if @resolved
      self
    end

    # supposed to be called by the receiver
    def error(&block)
      @error = block
      resolve_error(@arg_error) if @failed
      self
    end

    # supposed to be called by the receiver
    def cancel
      @canceled = true
      @cancel&.call(error)
    end

    # supposed to be called by the creator
    def resolve(*args)
      @resolved = true
      @args = args
      @callback&.call(*args)
    end

    # supposed to be called by the creator
    def resolve_error(error)
      @failed = true
      @arg_error = error
      @error&.call(error)
    end

    # supposed to be called by the creator
    def on_cancel(&block)
      @cancel = block
      cancel if @canceled
      self
    end
  end
end
