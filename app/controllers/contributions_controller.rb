require_relative '../models/grunt'
require_relative '../models/contribution_approval_request'
require_relative '../models/state'

class ContributionsController < ApplicationController

  SLACK_CHANNEL = 'hey-pie-slack-test'
  SLACK_BOT_TOKEN = ENV.fetch("SLACK_BOT_TOKEN")

  def events
    if params["type"] == "url_verification"
      challenge = params["challenge"]

      render json: { "challenge": challenge } and return
    end

    ts = params["event"]["ts"]
    State.contribution_approval_request.id = ts
    p State.contribution_approval_request
  end

  # TODO: Consider using constraints to separate calls from Slack
  # https://guides.rubyonrails.org/routing.html#advanced-constraints
  def slack
    if params["trigger_id"] != nil
      trigger_id = params["trigger_id"]

      send_dialog!(trigger_id: trigger_id)
    else
      # approve / reject
      payload = JSON(params["payload"])
      hard_coded_ts = "1535477555.000100"

      if payload["type"] == "interactive_message"
        voter = payload["user"]["id"]
        grunt_voter = State.team.find do |g|
          g.name == voter
        end

        return if grunt_voter.nil?

        if payload["actions"].first["name"] == "Approve"
          if State.contribution_approval_request.approve(from: grunt_voter)
            if ts = State.contribution_approval_request.id
              client.chat_postMessage(channel: SLACK_CHANNEL, text: "`Approved by:` <@#{voter}>", attachments: [], as_user: false, thread_ts: ts)
            else
              p 'error: missing ts'
            end

            if State.contribution_approval_request.approved?
              if ts = State.contribution_approval_request.id
                client.chat_postMessage(channel: SLACK_CHANNEL, text: "`Finalized on the blockchain` :100:", attachments: [], as_user: false, thread_ts: ts)
                message = "`With this contribution, the pie's valuation is now estimated at $#{State.pie_estimated_valuation} USD.` :dollar:"
                client.chat_postMessage(channel: SLACK_CHANNEL, text: message, attachments: [], as_user: false, thread_ts: ts)
              else
                p 'error: missing ts'
              end
            end
          else
            if ts = State.contribution_approval_request.id
              client.chat_postEphemeral(channel: SLACK_CHANNEL, text: '`You already voted.`', attachment: [], as_user: false, user: grunt_voter.name, thread_ts: hard_coded_ts)
            else
              p 'error: missing ts'
            end
          end
        else
          if State.contribution_approval_request.reject(from: grunt_voter)
            if ts = State.contribution_approval_request.id
              client.chat_postMessage(channel: SLACK_CHANNEL, text: "`Rejected by:` <@#{voter}>", attachments: [], as_user: false, thread_ts: ts)
            else
              p 'error: missing ts'
            end
          else
            if ts = State.contribution_approval_request.id
              client.chat_postEphemeral(channel: SLACK_CHANNEL, text: '`You already voted.`', attachment: [], as_user: false, user: grunt_voter.name, thread_ts: ts)
            else
              p 'error: missing ts'
            end
          end
        end

        return
      end

      # contribution dialog submission
      submitter = payload["user"]["id"]
      time_in_hours = payload["submission"]["contribution_hours"]
      description = payload["submission"]["contribution_description"]
      contributed = payload["submission"]["contribution_to"]

      grunt = State.team.find { |obj| obj.name == contributed }

      return if grunt.nil?

      State.contribution_approval_request = ContributionApprovalRequest.new(id: nil, time_in_hours: time_in_hours, beneficiary: grunt, approvers: State.team)
      send_contribution_approval_request!(submitter: submitter, contributed: contributed, time_in_hours: time_in_hours, description: description)
      p State.contribution_approval_request
    end
  end

  def send_contribution_approval_request!(submitter:, contributed:, time_in_hours:, description:)
    slices_of_pie = (100_000 * 2 / 2000) * time_in_hours.to_f
    message = get_message(submitter: submitter, contributed: contributed, time_in_hours: time_in_hours, slices_of_pie: slices_of_pie, description: description)
    attachments = get_message_attachments

    client.chat_postMessage(channel: SLACK_CHANNEL, text: message, attachments: attachments, as_user: false)
  end

  def send_dialog!(trigger_id:)
    client.dialog_open(trigger_id: trigger_id, dialog: get_dialog)
  end

  def stringify(pie, slice_in_pie, contributor)
    sum = (pie.values.map(&:to_i).inject(:+) + slice_in_pie.to_i).to_f

    output = ""
    pie.each do |k, v|
      if k == contributor
        updated = (v.to_i + slice_in_pie.to_i)
        p = sprintf('%.2f', (updated / sum) * 100) + '%'
        prefix = "> <#{k}>: *#{v} + #{slice_in_pie} = #{updated} :pie: (#{p})*\n"
        output = prefix + output
      else
        p = sprintf('%.2f', (v.to_i / sum) * 100) + '%'
        output += "> <#{k}>: *#{v} :pie: (#{p})*\n"
      end
    end

    return output
  end

  def format(description)
    description.split("\n").map do |line|
      "> #{line}"
    end.join("\n")
  end

  def get_dialog
    {
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
  end

  def get_message(submitter:, contributed:, time_in_hours:, slices_of_pie:, description:)
    bot_user = "hey_pie"
    some_text = State.contribution_approval_request.requested_changes

    <<~SLACK_TEMPLATE
      _*TxHash:* <https://etherscan.io/tx/0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842|0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842>_
      _*From:* <@#{submitter}> (<https://etherscan.io/address/0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7|0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7>)_
      _*To:* <@#{bot_user}> (<https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code|0x8d12a197cb00d4747a1fe03395095ce2a5cc6819>)_
      _*SocialContract (d190379):* (<https://github.com/kanhirun/hey-pie-social-contract/blame/d190379a0dd2640df5bc6d9f1e08312a99db914c/README.md|view>) (<https://github.com/kanhirun/hey-pie-social-contract/edit/master/README.md|edit>)_

      *Request:*
      > <@#{submitter}> requested approval for *#{time_in_hours} HOURS* which would award *#{slices_of_pie} SLICES OF PIE* to *<@#{contributed}>*
      *Description:*
      > #{description}
      *Requested Changes:*
      #{some_text}
    SLACK_TEMPLATE
  end

  def get_message_attachments
    [
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
  end

  private
    def client
      @client ||= Slack::Web::Client.new(token: SLACK_BOT_TOKEN)
    end
end
