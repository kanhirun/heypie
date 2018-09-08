require_relative './concerns/error_handling'
require_relative './utils/slack_message_builder_better'
require_relative './utils/slack_message_builder'

class SlackController < ApplicationController
  include ErrorHandling::HttpStatusCodes

  rescue_from KeyError, with: :bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  before_action :check_whether_production_channel

  SLACK_BOT_TOKEN = ENV.fetch("SLACK_BOT_TOKEN")

  def check_whether_production_channel
    channel = params.dig("channel", "name") || params["channel_name"]

    if channel and channel == "hey-pie-contributions" and !Rails.env.production?
      client.chat_postMessage(
        channel: channel,
        text: "Sorry, the app is currently being tested. Please chat with kel if you want production support.",
        attachments: []
      )
      head(400)
    end
  end

  # a naive algorithm for interpreting text intending to
  # organize users to their contributions
  #
  # Example:
  # @alice @bob 10 @felix 3
  # to be read as, "alice and bob gets 10, felix gets 3."
  def process_command(text)
    tokens = text.split("\s")

    processed = tokens.map do |token|
      if token.starts_with?("@")
        token[1..token.length]
      else
        token.to_f
      end
    end

    results = {}
    deferred = []
    processed.each do |x|
      if x.is_a? String
        deferred << x
      elsif x.is_a? Numeric
        # flushes out
        deferred.each do |y|
          results[y] = x
        end
        deferred = []
      end
    end

    return nil if deferred.present?

    return results
  end

  def heypie_group_command
    channel = params.fetch("channel_id")
    text = params.fetch("text")
    submitter_name = params.fetch("user_id")

    users = client.users_list
    submitter = Grunt.find_by!(slack_user_id: submitter_name)

    # get only valid slack users
    # returns <members>
    matched_users = users.members.select do |member|
      text.include? member.name
    end

    # map: Slack(user name => user id)
    x = {}
    process_command(text).each do |name, hours|
      if found = matched_users.find{ |u| u.name == name }
        x[found.id] = hours
      end
    end

    # map: user id => grunt
    y = {}
    x.each do |id, hours|
      if found = Grunt.find_by(slack_user_id: id)
        y[found] = hours
      end
    end

    if y.present?
      contribution = Contribution.new(
        submitter: submitter,
        voters: Grunt.heypie_grunts
      )
      contribution.save!

      contribution.contribute_hours(y)

      message = SlackMessageBuilderBetter.new(contribution)

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

    beneficiary = Grunt.find_by!(slack_user_id: nominated)
    submitter   = Grunt.find_by!(slack_user_id: submitter_name)

    contribution = Contribution.new(
      submitter: submitter,
      voters: Grunt.heypie_grunts
    )
    contribution.contribute_hours(beneficiary => time_in_hours)
    contribution.save!

    formatter = SlackMessageBuilder.new(contribution, description, time_in_hours, beneficiary)
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
    payload = JSON(params.fetch("payload"))
    username = payload.fetch("user").fetch("id")
    origin = payload.fetch("channel").fetch("id")
    ts = payload.fetch("message_ts")

    voter = Grunt.find_by(slack_user_id: username)

    if voter.blank?
      render status: 404 and return 
    end

    req = Contribution.find_by(ts: ts)

    if req.nil?
      puts 'could not find ts'
      render status: 500 and return
    end

    begin
      if payload["actions"].first["name"] == "Approve"
        if req.approve!(from: voter)
          client.chat_postMessage(
            channel: origin,
            text: "`Approved by:` <@#{voter.slack_user_id}>",
            attachments: [],
            as_user: false,
            icon_url: voter.slack_icon_url,
            username: voter.slack_username,
            thread_ts: ts)

          if req.process
            client.chat_postMessage(
              channel: origin,
              text: "`Finalized on the blockchain` :100:",
              attachments: [],
              as_user: false,
              thread_ts: ts)
            message = "`With this contribution, the pie's valuation is now estimated at $#{State.pie_estimated_valuation} USD.` :dollar:"
            client.chat_postMessage(channel: origin, text: message, attachments: [], as_user: false, thread_ts: ts)
          end
        end
      else
        if req.reject!(from: voter)
          client.chat_postMessage(
            channel: origin,
            text: "`Rejected by:` <@#{voter.slack_user_id}>",
            attachments: [],
            as_user: false,
            icon_url: voter.slack_icon_url,
            username: voter.slack_username,
            thread_ts: ts)
        end
      end
    rescue AlreadyVotedError
      client.chat_postEphemeral(channel: origin, text: '`You already voted.`', attachment: [], as_user: false, user: voter.slack_user_id, thread_ts: ts)
    end

    return
  end

  def events
    if params["type"] == "url_verification"
      challenge = params["challenge"]

      render json: { "challenge": challenge } and return
    end

    ts = params["event"]["ts"]
    if req = Contribution.last
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
