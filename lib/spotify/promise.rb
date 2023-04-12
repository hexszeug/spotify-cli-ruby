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

    ##
    # supposed to be called by the ***receiver***
    #
    # registers passed block as callback to call when promise resolves
    #
    # the block is called instantly if the promise was already resolved
    #
    # @return [Promise] self
    def callback(&block)
      @callback = block
      resolve(*@args) if @resolved
      self
    end

    ##
    # supposed to be called by the ***receiver***
    #
    # registers passed block as error handler to call when promise fails
    #
    # the block is called instantly if the promise did already fail
    #
    # @return [Promise] self
    def error(&block)
      @error = block
      fail(@arg_error) if @failed

      self
    end

    ##
    # supposed to be called by the ***receiver***
    #
    # cancels the action performed by the *creator*
    #
    # @return [nil]
    def cancel
      @canceled = true
      @cancel&.call(@arg_error)
    end

    ##
    # supposed to be called by the ***creator***
    #
    # @return [nil]
    def resolve(*args)
      @resolved = true
      @args = args
      @callback&.call(*args)
    end

    ##
    # supposed to be called by the ***creator***
    #
    # @return [nil]
    def fail(error)
      @failed = true
      @arg_error = error
      @error&.call(error)
    end

    ##
    # supposed to be called by the ***creator***
    #
    # should be called to setup the the routine
    # needed to cancel the action when the *receiver*
    # calls #cancel on the promise
    #
    # @return [Promise] self
    def on_cancel(&block)
      @cancel = block
      cancel if @canceled
      self
    end
  end
end
