require 'rails_helper'

require_relative '../../../app/controllers/utils/slack_message_builder'

# todo: fix these issues
describe SlackMessageBuilder do

  it 'integrates' do
    alice = Grunt.create!(slack_user_id: "Alice", base_salary: 1_000)
    contribution = Contribution.create!(
      submitter: alice,
      voters: [alice]
    )
    contribution.contribute_hours(alice => 5)

    subject = SlackMessageBuilder.new(contribution, "first line\nsecond line")

    text = subject.build.first

    expect(text).to eql <<~SLACK_TEMPLATE
      _*TxHash:* <https://etherscan.io/tx/0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842|0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842>_
      _*From:* <@Alice> (<https://etherscan.io/address/0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7|0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7>)_
      _*To:* <@hey_pie_test> (<https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code|0x8d12a197cb00d4747a1fe03395095ce2a5cc6819>)_
      _*SocialContract (d190379):* (<https://github.com/kanhirun/hey-pie-social-contract/blame/d190379a0dd2640df5bc6d9f1e08312a99db914c/README.md|view>) (<https://github.com/kanhirun/hey-pie-social-contract/edit/master/README.md|edit>)_

      *Request:*
      > <@Alice> requested approval for *5.0 HOURS* which would award *5 SLICES OF PIE* to *<@Alice>*
      *Description:*
      > first line
      > second line
      *Requested Changes:*
      > *<@Alice>: 0 + 5 = 5* :pie:
    SLACK_TEMPLATE
  end

  it 'prints right' do
    alice = Grunt.new(slack_user_id: "Alice")
    contribution = Contribution.new(submitter: alice)

    subject = SlackMessageBuilder.new(contribution)

    text = subject.header

    expect(text).to eql <<~SLACK_TEMPLATE
      _*TxHash:* <https://etherscan.io/tx/0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842|0x6267ffe683c9f268189e4042f3b2b4cf33e51193ac6b2e82ed7e733f47a3c842>_
      _*From:* <@Alice> (<https://etherscan.io/address/0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7|0x1038ae6fcd73a1846f8ea6ac1ff3a4fe57eb76d7>)_
      _*To:* <@hey_pie_test> (<https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code|0x8d12a197cb00d4747a1fe03395095ce2a5cc6819>)_
      _*SocialContract (d190379):* (<https://github.com/kanhirun/hey-pie-social-contract/blame/d190379a0dd2640df5bc6d9f1e08312a99db914c/README.md|view>) (<https://github.com/kanhirun/hey-pie-social-contract/edit/master/README.md|edit>)_
    SLACK_TEMPLATE
  end

  it 'for single' do
    bob = Grunt.create!(slack_user_id: "Bob", base_salary: 1_000)
    contribution = Contribution.create!(submitter: bob, voters: [])
    contribution.contribute_hours(bob => 5)
    contribution.process!

    subject = SlackMessageBuilder.new(contribution)

    text = subject.request_body

    expect(text).to eql <<~SLACK_TEMPLATE
      *Request:*
      > <@Bob> requested approval for *5.0 HOURS* which would award *5 SLICES OF PIE* to *<@Bob>*
    SLACK_TEMPLATE
  end

  it 'for many' do
    bob = Grunt.create!(slack_user_id: "Bob", base_salary: 1_000)
    alice = Grunt.create!(slack_user_id: "Alice", base_salary: 1_000)
    contribution = Contribution.create!(submitter: bob, voters: [])
    contribution.contribute_hours(bob => 5, alice => 10)
    contribution.process!

    subject = SlackMessageBuilder.new(contribution)

    text = subject.request_body

    expect(text).to eql <<~SLACK_TEMPLATE
      *Request:*
      > <@Bob> requested approval to award and recognize *<@Bob>, <@Alice>*
    SLACK_TEMPLATE
  end

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

      subject = SlackMessageBuilder.new(Contribution.new)

      expect(subject.quote(large_text)).to eql results.chomp
    end
  end

  describe '#requested_changes(req)' do
    xit "returns each person's pie" do
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

  it 'sorts like a leaderboard' do
    alice = Grunt.create(slack_user_id: "alice")
    bob = Grunt.create(slack_user_id: "bob")

    old = Contribution.create!(
      submitter: Grunt.new,
      voters: [bob, alice]
    )
    old.nominations.create!({ grunt: bob, slices_of_pie_to_be_rewarded: 1, contribution: old, awarded: true })

    contribution = Contribution.create!(
      submitter: Grunt.new,
      voters: [bob, alice]
    )
    contribution.nominations.create!(
      { grunt: alice, slices_of_pie_to_be_rewarded: 9999 }
    )

    results = SlackMessageBuilder.new(contribution).requested_changes

    expect(results).to eql <<~SLACK_FORMATTED
     *Requested Changes:*
     > *<@alice>: 0 + 9999 = 9999* :pie:
     > <@bob>: 1 + 0 = 1 :pie:
    SLACK_FORMATTED
    end
  end
