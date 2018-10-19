class SlackMessageBuilder

  BOT_USERNAME = "heypie"

  def initialize(model, description = nil)
    @model = model
    @description = description
  end

  def build
    text = header + "\n" + request_body + description + requested_changes

    attachments = [
      {
        fallback: "Make your decisions here: https://thepieslicer.com/home/2580",
        callback_id: "contribution",
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

    return text, attachments
  end

  def header
    submitter = @model.submitter.slack_user_id

    <<~SLACK_TEMPLATE
      _*TxHash:* <https://etherscan.io/tx/0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842|0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842>_
      _*From:* <@#{submitter}> (<https://etherscan.io/address/0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7|0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7>)_
      _*To:* <@#{BOT_USERNAME}> (<https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code|0x8d12a197cb00d4747a1fe03395095ce2a5cc6819>)_
      _*SocialContract (d190379):* (<https://github.com/kanhirun/hey-pie-social-contract/blame/d190379a0dd2640df5bc6d9f1e08312a99db914c/README.md|view>) (<https://github.com/kanhirun/hey-pie-social-contract/edit/master/README.md|edit>)_
    SLACK_TEMPLATE
  end

  def request_body
    submitter = @model.submitter.slack_user_id

    if @model.nominated_grunts.many?
      many = @model.nominated_grunts.map do |grunt|
        "<@#{grunt.slack_user_id}>"
      end.join(', ')

      return <<~SLACK_TEMPLATE
        *Request:*
        > <@#{submitter}> requested approval to award and recognize *#{many}*
      SLACK_TEMPLATE
    else
      # one grunt
      to = @model.nominated_grunts.first
      n = Nomination.where(grunt: to, contribution: @model).first
      time_in_hours = n.time_in_hours
      slices_of_pie = n.slices_of_pie_to_be_rewarded

      return <<~SLACK_TEMPLATE
        *Request:*
        > <@#{submitter}> requested approval for *#{time_in_hours} HOURS* which would award *#{slices_of_pie} SLICES OF PIE* to *<@#{to.slack_user_id}>*
      SLACK_TEMPLATE
    end
  end

  def description
    return "" if @description.nil?

    <<~SLACK_TEMPLATE
      *Description:*
      #{quote(@description)}
    SLACK_TEMPLATE
  end

  def requested_changes
    msg = "*Requested Changes:*\n"

    @model.voters
      .sort_by do |x|
        if nomination = Nomination.find_by(grunt: x, contribution: @model)
          -(x.slices_of_pie + nomination.slices_of_pie_to_be_rewarded)
        else
          -x.slices_of_pie
        end
      end
     .each do |voter|
        if nomination = Nomination.find_by(grunt: voter, contribution: @model)
          start = nomination.grunt.slices_of_pie
          diff = nomination.slices_of_pie_to_be_rewarded
          msg += "> *<@#{nomination.grunt.slack_user_id}>: #{start} + #{diff} = #{start + diff}* :pie:\n"
        else
          msg += "> <@#{voter.slack_user_id}>: #{voter.slices_of_pie} + 0 = #{voter.slices_of_pie} :pie:\n"
        end
      end

    return msg
  end

  def quote(many_lines_of_text)
    many_lines_of_text.split("\n").map do |line|
      "> #{line}"
    end.join("\n")
  end
end

