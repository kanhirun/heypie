Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  get '/auth', to: 'slack#authenticate'

  post '/slack/commands/heypie',       to: 'slack#heypie_command'
  post '/slack/commands/heypie-group', to: 'slack#heypie_group_command'
  post '/slack/interactions',          to: 'slack#dialog_submission', constraints: lambda { |req| JSON(req.params["payload"])["type"] == "dialog_submission" }
  post '/slack/interactions',          to: 'slack#vote_on_request', constraints: lambda { |req| JSON(req.params["payload"])["type"] == "interactive_message" }
  post '/slack/events',                to: 'slack#events'
end
