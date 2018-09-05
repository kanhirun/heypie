require 'rails_helper'

RSpec.describe SlackController, type: :controller do
  describe 'POST /slack/slash_commands/heypie' do
    it 'opens a dialog' do
      client = instance_double('Slack::Client')
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
      controller.client = client

      expect(client).to receive(:dialog_open).with({ trigger_id: "some-trigger-id", dialog: dialog })

      post :heypie_command, params: { "command": '/heypie', "trigger_id": "some-trigger-id"}

      # todo: expect(response).to have_http_status :ok
      expect(response).to have_http_status :no_content
    end

    it "returns 504 SERVICE UNAVAILABLE when the server isn't fast enough" do
      mock_client = instance_double("SlackClient")
      allow(mock_client).to receive(:dialog_open).with(anything()) do
        raise Slack::Web::Api::Errors::SlackError.new("timeout")
      end
      controller.client = mock_client

      post :heypie_command, params: { "trigger_id": "99999999" }

      expect(response).to have_http_status 504
    end

    it 'returns 400 BAD REQUEST if request is malformed' do
      client = instance_double('Slack::Client')
      controller.client = client

      post :heypie_command, params: {}

      expect(response).to have_http_status :bad_request
    end
  end


  describe 'POST /slack/interactive_messages/dialog_submission' do
    it "returns 404 error when user doesn't exist" do
      client = instance_double('Slack::Client')
      controller.client = client
      does_not_exist = "DOES_NOT_EXIST"
      jsonified = {
        "type": "dialog_submission",
        "channel": { "id": "some-channel-id" },
        "user": { "id": "some-user-id" },
        "submission": {
          "contribution_hours": "22.0",
          "contribution_description": "Lorem ipsum",
          "contribution_to": does_not_exist
        }
      }
      params = {
        "payload": JSON(jsonified)
      }

      post :dialog_submission, params: params

      expect(response).to have_http_status :not_found
    end

    it 'returns 400 BAD REQUEST if the request data is unexpected' do
      Grunt.create!(name: "Alice")

      client = instance_double('Slack::Client')
      controller.client = client
      params = {}

      post :dialog_submission, params: params

      expect(response).to have_http_status :bad_request
    end

    it 'returns 200 OK if user is found' do
      Grunt.create!(name: "Alice")
      Grunt.create!(name: "Submitter")

      client = instance_double('Slack::Client', chat_postMessage: nil)
      controller.client = client
      alice = "Alice"
      submitter = "Submitter"
      jsonified = {
        "type": "dialog_submission",
        "channel": { "id": "some-channel-id" },
        "user": { "id": submitter},
        "submission": {
          "contribution_hours": "22.0",
          "contribution_description": "Lorem ipsum",
          "contribution_to": alice
        }
      }
      params = {
        "payload": JSON(jsonified)
      }

      post :dialog_submission, params: params

      # todo: not sure why slack doesn't like this?
      # expect(response).to have_http_status :ok
      expect(response).to have_http_status :no_content
    end
  end

  describe 'POST /slack/events' do
    it 'returns the challenge' do
      params = {
        'type': 'url_verification',
        'challenge': 'some-challenge'
      }

      post :events, params: params

      expect(response.body).to eql({ 'challenge': 'some-challenge' }.to_json)
    end

    it 'sets the ts' do
      params = {
        'event': {
          'ts': 'some-ts'
        }
      }
      ContributionApprovalRequest.create!(submitter: Grunt.create!(name: 'submitter'))

      post :events, params: params

      expect(ContributionApprovalRequest.last.ts).to eql 'some-ts'
    end
  end

  describe '#requested_changes(req)' do
    it "returns each person's pie" do
      alice = Grunt.new(name: "alice")
      bob = Grunt.new(name: "bob")
      alice.slices_of_pie = 258
      bob.slices_of_pie = 10
      req = ContributionApprovalRequest.create!(
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
end
