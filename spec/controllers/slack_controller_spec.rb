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

  # todo: move me
  describe 'process_command' do 
    it 'does it' do
      text = "@alice 22"

      results = controller.process_command(text)

      expect(results).to eql({ "alice" => 22 })
    end

    it 'does it' do
      text = "@alice @bob 100"

      results = controller.process_command(text)

      expect(results).to eql({ 
        "alice" => 100,
        "bob" => 100
      })
    end

    it 'does it' do
      text = "@alice 11 @bob 22"

      results = controller.process_command(text)

      expect(results).to eql({ 
        "alice" => 11,
        "bob" => 22
      })
    end

    it 'is can handle weird spaces' do
      text = "@alice      333 @bob @james   999"

      results = controller.process_command(text)

      expect(results).to eql({ 
        "alice" => 333,
        "bob" => 999,
        "james" => 999
      })
    end

    it 'returns nil when shit' do
      text = "@alice @bob @james"

      results = controller.process_command(text)

      expect(results).to be nil
    end
  end

  xdescribe 'POST /slack/slash_commands/heypie-group' do
    it '/heypie-group @alice 22' do
      Grunt.create!(name: "alice-id")

      mock_client = instance_double('SlackClient')
      controller.client = mock_client
      stubbed = Slack::Messages::Message.new({
          members: [
            {
              id: "alice-id",
              profile: {
                display_name: "alice"
              }
            },
            {
              id: "bob-id",
              profile: {
                display_name: "bob"
              }
            }
          ]
      })
      allow(mock_client).to receive(:users_list).and_return(stubbed)
      expect(mock_client).to receive(:chat_postMessage).with(hash_including(
        text: "Hello, <@alice-id>!"
      ))

      command = from_slack('/heypie-group @alice 22')
        .merge({ "channel_id": "9999"})

      post :heypie_group_command, params: command
    end

    it '/heypie-group @alice @bob 5.0' do
      group = from_slack '/heypie-group @alice @bob 5.0'

      post :heypie_group_command, params: group

      expect(response).to have_http_status 501
      # expect(response).to have_http_status 200
    end

    it '/heypie-group @alice 10 @bob 5' do
      custom = from_slack '/heypie-group @alice 10 @bob 5'
      bob = Grunt.new

      expect do
        post :heypie_group_command, params: custom
      end.to change { bob.slices_of_pie }.by(5)

      expect(response).to have_http_status 501
      # expect(response).to have_http_status 200
    end

    it '/heypie-group @here 10' do
    end

    it 'errors when the command is malformed' do
      empty = from_slack '/heypie-group'

      post :heypie_group_command, params: empty

      expect(response).to have_http_status 400
    end

    it 'errors when the command is malformed' do
      no_time_specified = from_slack '/heypie-group @alice'

      post :heypie_group_command, params: no_time_specified

      expect(response).to have_http_status 400
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
      alice = Grunt.create!(name: "Alice")
      Grunt.create!(name: "Submitter")

      client = instance_double('Slack::Client', chat_postMessage: nil)
      controller.client = client
      alice_name = "Alice"
      submitter = "Submitter"
      jsonified = {
        "type": "dialog_submission",
        "channel": { "id": "some-channel-id" },
        "user": { "id": submitter},
        "submission": {
          "contribution_hours": "22.0",
          "contribution_description": "Lorem ipsum",
          "contribution_to": alice_name
        }
      }
      params = {
        "payload": JSON(jsonified)
      }

      post :dialog_submission, params: params

      alice.reload

      # todo: not sure why slack doesn't like this?
      # expect(response).to have_http_status :ok

      contribution = ContributionApprovalRequest.last
      contribution.voters = []
      contribution.process
      contribution.save!

      alice.reload

      expect(alice.slices_of_pie).to eql((22 * alice.hourly_rate).to_i)
      expect(contribution.votes.length).to eql 0
      expect(contribution.voters.length).to eql 0
      expect(response).to have_http_status :no_content
    end
  end

  describe 'voting' do
    it 'rejects a vote' do
      alice = Grunt.new(name: "Alice")
      bob = Grunt.new(name: "Bob")  # is the voter
      model = ContributionApprovalRequest.new(
        submitter: Grunt.new,
        voters: [alice, bob],
        ts: "my-ts"
      )
      mock_client = instance_double("NullClient").as_null_object
      controller.client = mock_client

      model.maybe_contribute_hours({
        bob => 10,
        alice => 5
      })

      model.save!

      params = JSON({
        "user": { "id": "Bob" },  # here it is
        "channel": { "id": "some-channel-id" },
        "message_ts": "my-ts",  # and here it is
        "actions": [
          {"name": "Reject"}
        ]
      })

      post :vote_on_request, params: { payload: params }

      alice.reload

      expect(model.processed).to be false
      expect(alice.slices_of_pie).to eql 0
      expect(response).to have_http_status 204
    end

    it 'accepts a vote' do
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
end

# todo: move me to DSL
# makes it easier to read test code
# todo: use re to capture groups etc
def from_slack(input)
  command_pattern = /(\/[a-zA-Z\-\_]+)(.*)/

  if matched = command_pattern.match(input)
    command, text = matched[1], matched[2]

    return { 'command': command, 'text': text }
  else
    raise StandardError.new
  end
end

