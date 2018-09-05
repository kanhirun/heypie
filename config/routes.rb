Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # post '/contributions', to: 'contributions#slack'
  # post '/contributions/new', to: 'contributions#new'

  post '/slack/slash_commands/heypie', to: 'slack#heypie_command'
  post '/slack/interactive_components', to: 'slack#dialog_submission',
    constraints: lambda { |req| JSON(req.params["payload"])["type"] == "dialog_submission" }
  post '/slack/interactive_components', to: 'slack#vote_on_request',
    constraints: lambda { |req| JSON(req.params["payload"])["type"] == "interactive_message" }
  post '/slack/events', to: 'slack#events'

  post '/events', to: 'contributions#events'
end
