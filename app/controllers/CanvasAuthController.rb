# app/controllers/canvas_auth_controller.rb
class CanvasAuthController < ApplicationController
  def start
  client_id     = ENV['CANVAS_CLIENT_ID']
  redirect_uri  = canvas_callback_url
  canvas_domain = ENV['CANVAS_DOMAIN'] || 'canvas.instructure.com'
  scope         = 'url:GET|/api/v1/courses'

  authorization_url = "https://#{canvas_domain}/login/oauth2/auth?client_id=#{client_id}&response_type=code&redirect_uri=#{CGI.escape(redirect_uri)}&scope=#{CGI.escape(scope)}"
  
  redirect_to authorization_url, allow_other_host: true
  end
  # Optionally, add a callback action to handle Canvas's redirect after authorization
  def callback
    # Here you'll handle the OAuth callback from Canvas:
    # - Exchange the authorization code for an access token.
    # - Save the token to the user’s account (perhaps via session or after account creation).
    # For now, you might just render a simple message.
    render plain: "Canvas OAuth callback reached. Process the authorization code here."
  end
end