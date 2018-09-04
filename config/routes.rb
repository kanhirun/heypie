Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # post '/contributions', to: 'contributions#slack'
  # post '/contributions/new', to: 'contributions#new'

  post '/slack/slash_commands/heypie', to: 'slack#heypie_command'
  post '/slack/interactive_components/dialog_submission', to: 'slack#dialog_submission'
  post '/slack/events', to: 'slack#events'

  post '/events', to: 'contributions#events'
end
