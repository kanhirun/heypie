class SlackController < ApplicationController

  SLACK_BOT_TOKEN = ENV.fetch("SLACK_BOT_TOKEN")

  def heypie_command
    trigger_id = params["trigger_id"]
    dialog = {
        "callback_id": "ryde-46e2b0",
        "title": "Hey! Ready to request?", # 24 char
        "submit_label": "Yeah_I_am!",  # one word contraint
        "elements": [
          {
            "label": "Who did the work?", # 24 char
            "name": "contribution_to",
            "type": "select",
            "data_source": "users"
          },
          {
            "label": "How long was it? ex 1.75",
            "type": "text",
            "subtype": "number",
            "name": "contribution_hours"
          },
          {
            "label": "Describe it for me.",
            "type": "textarea",
            "name": "contribution_description",
            "hint": "Provide additional information if needed."
          }
        ]
    }

    client.dialog_open(trigger_id: trigger_id, dialog: dialog)
  end

  def dialog_submission
    nominated = params["payload"]["submission"]["contribution_to"]

    beneficiary = Grunt.find_by(name: nominated)

    render status: 404 and return if beneficiary.nil?

    render status: 200
  end

  def client
    @client ||= Slack::Web::Client.new(token: SLACK_BOT_TOKEN)
  end

  # for testing
  def client=(new_client)
    @client = new_client
  end
end
