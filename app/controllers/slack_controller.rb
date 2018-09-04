class SlackController < ApplicationController

  SLACK_BOT_TOKEN = ENV["SLACK_BOT_TOKEN"]

  def heypie_command
    trigger_id = params.fetch("trigger_id")

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

    # todo: error handle
    client.dialog_open(trigger_id: trigger_id, dialog: dialog)

    render status: 200
  end

  def dialog_submission
    begin
      deserialized = JSON(params.fetch("payload"))

      nominated     = deserialized.fetch("submission").fetch("contribution_to")
      origin        = deserialized.fetch("channel").fetch("id")
      submitter     = deserialized.fetch("user").fetch("id")
      time_in_hours = deserialized.fetch("submission").fetch("contribution_hours")
      description   = deserialized.fetch("submission").fetch("contribution_description")
    rescue KeyError
      # todo use a logger to capture error
      render status: 400 and return
    end

    beneficiary = Grunt.find_by(name: nominated)

    render status: 404 and return if beneficiary.nil?

    _ = ContributionApprovalRequest.new
    message = "Testing"
    attachments = [
      {
        fallback: "Make your decisions here: https://thepieslicer.com/home/2580",
        callback_id: "contribution_approval_request",
        text: "Would you like to *approve*, *amend*, or *reject* this contribution?",
        actions: [
          {
            type: "button",
            name: "Approve",
            text: "Approve :heavy_check_mark:",
            style: "primary",
            value: "approve"
          },
          {
            type: "button",
            name: "Reject",
            text: "Reject :no_entry_sign:",
            style: "danger",
            value: "reject"
          }
        ]
      }
    ]

    # todo: capture slack error
    client.chat_postMessage(
      channel: origin,
      text: message,
      attachments: attachments,
      as_user: false
    )

    render status: 200 and return
  end

  def client
    @client ||= Slack::Web::Client.new(token: SLACK_BOT_TOKEN)
  end

  # for testing
  def client=(new_client)
    @client = new_client
  end
end
