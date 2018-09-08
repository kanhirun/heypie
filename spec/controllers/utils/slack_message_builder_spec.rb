require_relative '../../../app/controllers/utils/slack_message_builder'

# todo: fix these issues
xdescribe SlackMessageBuilder do
  describe 'format_description(text)' do
    it 'quotes very long text' do
      large_text = <<~RAW_TEXT
        aaaaaaaaaaaaaaaa
        bbbbbbbbbbb
        ccccccc
        ddddd
        eee
        f
      RAW_TEXT

      results = <<~SLACK_FORMATTED
        > aaaaaaaaaaaaaaaa
        > bbbbbbbbbbb
        > ccccccc
        > ddddd
        > eee
        > f
      SLACK_FORMATTED

      expect(controller.formatter.quote(large_text)).to eql results.chomp
    end
  end

  describe '#requested_changes(req)' do
    it "returns each person's pie" do
      alice = Grunt.new(name: "alice")
      bob = Grunt.new(name: "bob")
      alice.slices_of_pie = 258
      bob.slices_of_pie = 10
      req = Contribution.create!(
        submitter: Grunt.new,
        voters: [bob, alice]
      )

      req.nominations.create!({
        grunt: bob,
        slices_of_pie_to_be_rewarded: 100
      })

      results = controller.formatter.requested_changes(req)

      expect(results).to eql <<~SLACK_FORMATTED
       > <@bob>: 10 + 100 = 110 :pie:
       > <@alice>: 258 + 0 = 258 :pie:
      SLACK_FORMATTED
    end
  end
end
