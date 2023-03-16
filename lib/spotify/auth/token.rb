# frozen_string_literal: true

module Spotify
  module Auth
    module Token
      TOKEN_DIR = "#{Dir.home}/.spotify-cli-ruby"
      TOKEN_PATH = "#{TOKEN_DIR}/token.json"

      class << self
        def token?
          @token ? true : false
        end

        def access_token
          @token ? @token[:access_token].dup : nil
        end

        def refresh_token
          @token ? @token[:refresh_token].dup : nil
        end

        def expires_at
          @token ? @token[:expires_at].dup : nil
        end

        def expires_in
          @token ? @token[:expires_at] - Time.now.to_i : nil
        end

        def save_token
          return false unless @token

          begin
            token_json = JSON.pretty_generate @token
          rescue JSON::JSONError
            return false
          end
          Dir.mkdir TOKEN_DIR unless Dir.exist? TOKEN_DIR
          File.write TOKEN_PATH, "#{token_json}\n"
          true
        end

        def load_token
          return false unless File.file? TOKEN_PATH

          begin
            token_hash = JSON.parse File.read(TOKEN_PATH), symbolize_names: true
            set_token token_hash
          rescue JSON::JSONError, TokenError
            return false
          end
          true
        end

        def set_token(token_hash)
          raise TokenError, 'token must be a hash' unless token_hash.is_a? Hash

          token = token_hash.dup
          token.delete_if do |key|
            !%i[access_token refresh_token expires_in expires_at].include? key
          end
          unless token.key?(:access_token) && token[:access_token].is_a?(String)
            raise TokenError, 'missing access token'
          end

          if token.key?(:expires_in) && !token.key?(:expires_at) &&
             token[:expires_in].is_a?(Integer)
            token[:expires_at] = Time.now.to_i + token[:expires_in]
          end
          token.delete :expires_in
          unless token.key?(:expires_at) && token[:expires_at].is_a?(Integer)
            raise TokenError, 'missing expiration infomation'
          end

          if token.key?(:refresh_token) &&
             token[:refresh_token].is_a?(String)
            @token = token
          else
            raise TokenError, 'missing refresh token' unless @token

            @token.update token
          end
          refresh_token {} if Time.now.to_i >= token[:expires_at]
        end
      end
    end
  end
end
