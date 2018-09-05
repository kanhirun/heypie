# a formatting library for slack message template for contribution approval requests
class SlackFormatter

  # general
  def self.quote(many_lines_of_text)
    many_lines_of_text.split("\n").map do |line|
      "> #{line}"
    end.join("\n")
  end

  # domain-specific messaging
  def self.requested_changes(contribution_approval_request)
    msg = ""

    contribution_approval_request.voters.each do |voter|
      if nomination = Nomination.find_by(grunt: voter,
          contribution_approval_request: contribution_approval_request)
        start = nomination.grunt.slices_of_pie
        diff = nomination.slices_of_pie_to_be_rewarded
        msg += "> <@#{nomination.grunt.name}>: #{start} + #{diff} = #{start + diff} :pie:\n"
      else
        msg += "> <@#{voter.name}>: #{voter.slices_of_pie} + 0 = #{voter.slices_of_pie} :pie:\n"
      end
    end

    return msg
  end
end

