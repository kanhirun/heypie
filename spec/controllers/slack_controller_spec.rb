require 'rails_helper'

RSpec.describe SlackController, type: :controller do
  describe 'POST /slack/slash_commands/heypie' do
    it 'opens a dialog' do
      client = instance_double('Slack::Client')
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
      controller.client = client

      expect(client).to receive(:dialog_open).with({ trigger_id: "some-trigger-id", dialog: dialog })

      post :heypie_command, params: { "command": '/heypie', "trigger_id": "some-trigger-id"}
    end
  end
end
