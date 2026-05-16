class TrackingController < ApplicationController
  def open
    send_record = EmailFlowSend.find_by(tracking_token: params[:token])
    send_record&.mark_opened!

    # 1x1 transparent pixel
    pixel = Base64.decode64('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')
    send_data pixel, type: 'image/gif', disposition: 'inline'
  end
end
