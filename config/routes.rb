Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  get '/oauth/redirect', to: 'slack#oauth_redirect'

  post '/slack/commands/pie', to: 'slack#pie_command'
  post '/slack/interactions', to: 'slack#submit', constraints: lambda { |req| JSON(req.params["payload"])["type"] == "dialog_submission" }
  post '/slack/interactions', to: 'slack#vote', constraints: lambda { |req| JSON(req.params["payload"])["type"] == "interactive_message" }
  post '/slack/events',       to: 'slack#events'
end
