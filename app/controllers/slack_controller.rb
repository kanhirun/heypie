require_relative './concerns/error_handling'
require_relative './utils/slack_message_builder'

module Validator
  # Returns true/false depending on whether the signatures match between the client
  # and server
  def authenticated?(request)
    ts              = request.headers["X-Slack-Request-Timestamp"]
    body            = request.raw_post
    slack_signature = request.headers["X-Slack-Signature"]

    version              = "v0"
    sig_basestring       = [version, ts, body].join(":")
    slack_signing_secret = slack_credentials[:signing_secret]
    my_signature         = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", slack_signing_secret, sig_basestring)

    my_signature == slack_signature
  end
end


class SlackController < ApplicationController

  before_action :verify_requests, except: :oauth_redirect

  rescue_from 'ActionController::ParameterMissing' do |e|
    Rails.logger.error(e)
    head :bad_request
  end

  rescue_from 'ActiveRecord::RecordNotFound' do |e|
    Rails.logger.warn(e)
    head :not_found
  end

  def oauth_redirect
    if params[:error] == "access_denied"
      render plain: "You've denied permissions.", status: 400 and return
    elsif params[:code].present?
      client_id     = slack_credentials[:client_id]
      client_secret = slack_credentials[:client_secret]
      code          = params[:code]

      client.oauth_access(client_id: client_id, client_secret: client_secret, code: code)

      render plain: "Thanks! You're ready to try out Hey, Pie!", status: 200 and return
    end

    render plain: "Nothing to see here yet.", status: 200
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

  def pie_command
    arguments = params.fetch("text")

    if arguments.present?
      heypie_group_command
    else
      heypie_single_command
    end
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

      message = SlackMessageBuilder.new(contribution)

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

  def heypie_single_command
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
    rescue Slack::Web::Api::Errors::SlackError => e  # todo: target this error
      puts e
      render status: 504
    end
  end

  def submit
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

    formatter = SlackMessageBuilder.new(contribution, description)
    text, attachments = formatter.build

    # todo: capture slack error
    client.chat_postMessage(
      channel: origin,
      text: text,
      attachments: attachments,
      as_user: false
    )
  end

  def vote
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

  def verify_requests
    if !validator.authenticated?(request)
      render plain: "Signatures do not match.", status: 400
    end
  end

  def client
    token = slack_credentials[:bot_oauth_access_token]
    @client ||= Slack::Web::Client.new(token: token)
  end

  def validator
    @validator ||= Validator
  end

  private
    def slack_credentials
      Rails.application.credentials[:slack][ ENV.fetch('SLACK_WORKSPACE').to_sym ]
    end

    def client=(new_client)
      @client = new_client
    end

    def validator=(validator)
      @validator = validator
    end
end
