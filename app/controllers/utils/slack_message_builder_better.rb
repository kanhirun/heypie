class SlackMessageBuilderBetter

  # todo: too many args, but good enough for now
  def initialize(model)
    @model = model
  end

  def build
    bot_username = "hey_pie"
    submitter_name = @model.submitter.slack_user_id
    winners = @model.nominated_grunts.map do |g|
      "<@#{g.slack_user_id}>"
    end.join(",")

    text = <<~SLACK_TEMPLATE
      _*TxHash:* <https://etherscan.io/tx/0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842|0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842>_
      _*From:* <@#{submitter_name}> (<https://etherscan.io/address/0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7|0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7>)_
      _*To:* <@#{bot_username}> (<https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code|0x8d12a197cb00d4747a1fe03395095ce2a5cc6819>)_
      _*SocialContract (d190379):* (<https://github.com/kanhirun/hey-pie-social-contract/blame/d190379a0dd2640df5bc6d9f1e08312a99db914c/README.md|view>) (<https://github.com/kanhirun/hey-pie-social-contract/edit/master/README.md|edit>)_

      *Request:*
      > <@#{submitter_name}> requested approval for to award and recognize *#{winners}*
      *Requested Changes:*
      #{requested_changes}
    SLACK_TEMPLATE

    attachments = [
      {
        fallback: "Make your decisions here: https://thepieslicer.com/home/2580",
        callback_id: "contribution",
        text: "Would you like to *approve* or *reject* this contribution?",
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

  private
    def requested_changes
      msg = ""

      @model.voters.sort_by(&:slices_of_pie).each do |voter|
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

    def description(many_lines_of_text)
      many_lines_of_text.split("\n").map do |line|
        "> #{line}"
      end.join("\n")
    end
end

