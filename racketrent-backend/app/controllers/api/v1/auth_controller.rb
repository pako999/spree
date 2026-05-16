module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate!, only: [:login]

      def login
        admin = AdminUser.find_by(email: params[:email])
        if admin&.authenticate(params[:password])
          token = encode_token({ user_id: admin.id })
          render json: { token: token, admin: { id: admin.id, name: admin.name, email: admin.email, role: admin.role } }
        else
          render_error('Invalid email or password', status: :unauthorized)
        end
      end

      def me
        render json: { id: current_admin.id, name: current_admin.name, email: current_admin.email, role: current_admin.role }
      end
    end
  end
end
