module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate!

      private

      def authenticate!
        token = request.headers['Authorization']&.split(' ')&.last
        return render_unauthorized unless token

        payload = decode_token(token)
        @current_admin = AdminUser.find_by(id: payload['user_id']) if payload
        render_unauthorized unless @current_admin
      end

      def current_admin
        @current_admin
      end

      def decode_token(token)
        JWT.decode(token, jwt_secret, true, algorithm: 'HS256').first
      rescue JWT::DecodeError
        nil
      end

      def encode_token(payload)
        JWT.encode(payload.merge(exp: 30.days.from_now.to_i), jwt_secret, 'HS256')
      end

      def jwt_secret
        ENV.fetch('JWT_SECRET', Rails.application.secret_key_base)
      end

      def render_unauthorized
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      def render_not_found
        render json: { error: 'Not found' }, status: :not_found
      end

      def render_error(message, status: :unprocessable_entity)
        render json: { error: message }, status: status
      end
    end
  end
end
