require_relative './concerns/error_handling'
require_relative './utils/slack_message_builder'

class SlackController < ApplicationController
  include ErrorHandling::HttpStatusCodes

  rescue_from KeyError, with: :bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  SLACK_BOT_TOKEN = ENV["SLACK_BOT_TOKEN"]

  def heypie_group_command
    channel = params.fetch("channel_id")
    command = params.fetch("text")

    # todo: seems useful enough to extract..?
    def mention(id)
      "<@#{id}>"
    end

    users = client.users_list

    matched = users.members.find do |member|
      matching_name = member.dig(:profile, :display_name)
      command.include? matching_name
    end

    if matched && mentioned = Grunt.find_by(name: matched.id)
      model = ContributionApprovalRequest.new(
        submitter: mentioned
      )
      message = SlackMessageBuilder.new(model, "N/A", 999, mentioned)
      text, attachments = message.build

      client.chat_postMessage(
        channel: channel,
        text: text,
        attachments: attachments
      )

      render status: 204
    else
      render status: 404
    end
  end

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

    begin
      client.dialog_open(trigger_id: trigger_id, dialog: dialog)
      render status: 204
    rescue Slack::Web::Api::Errors::SlackError  # todo: target this error
      render status: 504
    end
  end

  def dialog_submission
    deserialized = JSON(params.fetch("payload"))

    nominated      = deserialized.fetch("submission").fetch("contribution_to")
    origin         = deserialized.fetch("channel").fetch("id")
    submitter_name = deserialized.fetch("user").fetch("id")
    time_in_hours  = deserialized.fetch("submission").fetch("contribution_hours")
    description    = deserialized.fetch("submission").fetch("contribution_description")

    beneficiary = Grunt.find_by!(name: nominated)
    submitter   = Grunt.find_by!(name: submitter_name)

    # ew, api
    # todo: defer creating the obj until /events
    model = ContributionApprovalRequest.create!(
      submitter: submitter
    )
    # todo: abstract me next!
    Grunt.all.each do |g|
      model.votes.create!(grunt: g)
    end
    model.maybe_contribute_hours(beneficiary => time_in_hours)
    model.save!

    formatter = SlackMessageBuilder.new(model, description, time_in_hours, beneficiary)
    text, attachments = formatter.build

    # todo: capture slack error
    client.chat_postMessage(
      channel: origin,
      text: text,
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

  def events
    if params["type"] == "url_verification"
      challenge = params["challenge"]

      render json: { "challenge": challenge } and return
    end

    ts = params["event"]["ts"]
    if req = ContributionApprovalRequest.last
      req.update({ts: ts})
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
