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
  end

  def dialog_submission
    begin
      deserialized = JSON(params.fetch("payload"))

      nominated      = deserialized.fetch("submission").fetch("contribution_to")
      origin         = deserialized.fetch("channel").fetch("id")
      submitter_name = deserialized.fetch("user").fetch("id")
      time_in_hours  = deserialized.fetch("submission").fetch("contribution_hours")
      description    = deserialized.fetch("submission").fetch("contribution_description")
    rescue KeyError
      # todo use a logger to capture error
      render status: 400 and return
    end

    beneficiary = Grunt.find_by(name: nominated)
    submitter = Grunt.find_by(name: submitter_name)

    render status: 404 and return if beneficiary.nil?

    # ew, api
    req = ContributionApprovalRequest.create!(
      submitter: submitter
    )
    Grunt.all.each do |g|
      req.votes << Vote.create!(contribution_approval_request: req, grunt: g)
    end
    req.nominations.create!({
      contribution_approval_request: req,
      grunt: beneficiary,
      slices_of_pie_to_be_rewarded: (time_in_hours.to_f * beneficiary.hourly_rate)
    })
    bot_username = "hey_pie"
    message = <<~SLACK_TEMPLATE
      _*TxHash:* <https://etherscan.io/tx/0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842|0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842>_
      _*From:* <@#{submitter.name}> (<https://etherscan.io/address/0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7|0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7>)_
      _*To:* <@#{bot_username}> (<https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code|0x8d12a197cb00d4747a1fe03395095ce2a5cc6819>)_
      _*SocialContract (d190379):* (<https://github.com/kanhirun/hey-pie-social-contract/blame/d190379a0dd2640df5bc6d9f1e08312a99db914c/README.md|view>) (<https://github.com/kanhirun/hey-pie-social-contract/edit/master/README.md|edit>)_

      *Request:*
      > <@#{submitter.name}> requested approval for *#{time_in_hours} HOURS* which would award *#{time_in_hours.to_f * beneficiary.hourly_rate} SLICES OF PIE* to *<@#{beneficiary.name}>*
      *Description:*
      > #{description}
      *Requested Changes:*
      #{get_requested_changes(req: req)}
    SLACK_TEMPLATE

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
  end

  def vote_on_request
    payload = JSON(params["payload"])
    username = payload["user"]["id"]
    origin = payload["channel"]["id"]
    ts = payload["message_ts"]

    voter = Grunt.find_by(name: username)

    render status: :not_found and return if voter.nil?

    req = ContributionApprovalRequest.find_by(ts: ts)

    if req.nil?
      puts 'could not find ts'
      render status: 500 and return
    end

    begin
      if payload["actions"].first["name"] == "Approve"
        if req.approve!(from: voter)
          client.chat_postMessage(channel: origin, text: "`Approved by:` <@#{voter.name}>", attachments: [], as_user: false, thread_ts: ts)

          if req.process
            client.chat_postMessage(channel: origin, text: "`Finalized on the blockchain` :100:", attachments: [], as_user: false, thread_ts: ts)
            message = "`With this contribution, the pie's valuation is now estimated at $#{State.pie_estimated_valuation} USD.` :dollar:"
            client.chat_postMessage(channel: origin, text: message, attachments: [], as_user: false, thread_ts: ts)
          end
        end
      else
        if req.reject!(from: voter)
          client.chat_postMessage(channel: origin, text: "`Rejected by:` <@#{voter.name}>", attachments: [], as_user: false, thread_ts: ts)
        end
      end
    rescue AlreadyVotedError
      client.chat_postEphemeral(channel: origin, text: '`You already voted.`', attachment: [], as_user: false, user: voter.name, thread_ts: ts)
    end

    return
  end

  def get_requested_changes(req:)
    msg = ""

    req.voters.each do |voter|
      if nomination = Nomination.find_by(grunt: voter, contribution_approval_request: req)
        start = nomination.grunt.slices_of_pie
        diff = nomination.slices_of_pie_to_be_rewarded
        msg += "> <@#{nomination.grunt.name}>: #{start} + #{diff} = #{start + diff} :pie:\n"
      else
        msg += "> <@#{voter.name}>: #{voter.slices_of_pie} + 0 = #{voter.slices_of_pie} :pie:\n"
      end
    end

    return msg
  end

  def events
    if params["type"] == "url_verification"
      challenge = params["challenge"]

      render json: { "challenge": challenge } and return
    end

    ts = params["event"]["ts"]
    if req = ContributionApprovalRequest.last
      req.ts = ts
      req.save!
    end
  end

  def client
    @client ||= Slack::Web::Client.new(token: SLACK_BOT_TOKEN)
  end

  # for testing
  def client=(new_client)
    @client = new_client
  end
end
