require 'rails_helper'

# disable for now until better solution around testing message verifier
xdescribe SlackController, type: :controller do
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

      post :heypie_command,
        params: {
          "command": '/heypie',
          "trigger_id": "some-trigger-id"
        },
        headers: {
          'X-Slack-Request-Timestamp': 'some-ts',  # this is incomplete
          'X-Slack-Signature': 'some-computed-value'
        }

      # todo: expect(response).to have_http_status :ok
      expect(response).to have_http_status :no_content
    end

    describe 'errors' do
      it "returns 504 when too slow for Slack" do
        # 504:
        # The server is currently unable to handle the request due to a temporary
        # overloading or maintenance of the server. The implication is that this is a
        # temporary condition which will be alleviated after some delay

        mock_client = instance_double("SlackClient")
        allow(mock_client).to receive(:dialog_open).with(anything()) do
          raise Slack::Web::Api::Errors::SlackError.new("timeout")
        end
        controller.client = mock_client

        post :heypie_command, params: { "trigger_id": "99999999" }

        expect(response).to have_http_status 504
      end

      it 'returns 400 if missing a param' do
        client = instance_double('Slack::Client')
        controller.client = client

        post :heypie_command, params: {}

        expect(response).to have_http_status :bad_request
      end
    end
  end

  # todo: move me
  describe 'process_command' do 
    it 'does it' do
      text = "@alice 22"

      results = controller.process_command(text)

      expect(results).to eql({ "alice" => 22.0 })
    end

    it 'does it' do
      text = "@alice 10.27"

      results = controller.process_command(text)

      expect(results).to eql({ "alice" => 10.27 })
    end

    it 'does it' do
      text = "@alice @bob 100"

      results = controller.process_command(text)

      expect(results).to eql({ 
        "alice" => 100.0,
        "bob" => 100.0
      })
    end

    it 'does it' do
      text = "@alice 11 @bob 22"

      results = controller.process_command(text)

      expect(results).to eql({ 
        "alice" => 11.0,
        "bob" => 22.0
      })
    end

    it 'is can handle weird spaces' do
      text = "@alice      333 @bob @james   999"

      results = controller.process_command(text)

      expect(results).to eql({ 
        "alice" => 333.0,
        "bob" => 999.0,
        "james" => 999.0
      })
    end

    it 'returns nil when shit' do
      text = "@alice @bob @james"

      results = controller.process_command(text)

      expect(results).to be nil
    end
  end

  describe 'POST /slack/slash_commands/heypie-group' do
    it '/heypie-group @alice 22' do
      alice = Grunt.create!(slack_user_id: "alice-id")

      mock_client = instance_double('SlackClient')
      controller.client = mock_client
      stubbed = Slack::Messages::Message.new({
          members: [
            {
              id: "alice-id",
              name: "alice"
            },
            {
              id: "bob-id",
              name: "bob"
            }
          ]
      })
      allow(mock_client).to receive(:users_list).and_return(stubbed)
      allow(mock_client).to receive(:chat_postMessage).and_return(nil)

      command = from_slack('/heypie-group @alice 22')
        .merge({ "channel_id": "9999", "user_id": "alice-id"})

      post :heypie_group_command, params: command

      contribution = Contribution.last

      contribution.voters = []
      contribution.save!
      results = contribution.process

      expect(results).to be true
      expect(alice.slices_of_pie.to_f).to eql(22 * alice.hourly_rate)
    end

    it '/heypie-group @alice @alice 10 @alice 5' do
    end

    it '/heypie-group @alice @bob 5.0' do
      alice = Grunt.create!(slack_user_id: "alice-id", base_salary: 10_000)
      bob = Grunt.create!(slack_user_id: 'bob-id', base_salary: 7_000)

      mock_client = instance_double('SlackClient')
      controller.client = mock_client
      stubbed = Slack::Messages::Message.new({
          members: [
            {
              id: "alice-id",
              name: "alice"
            },
            {
              id: "bob-id",
              name: "bob"
            }
          ]
      })
      allow(mock_client).to receive(:users_list).and_return(stubbed)
      allow(mock_client).to receive(:chat_postMessage).and_return(nil)

      command = from_slack('/heypie-group @alice @bob 5.0')
        .merge({ "channel_id": "9999", "user_id": "alice-id"})

      post :heypie_group_command, params: command

      contribution = Contribution.last
      contribution.voters = []
      contribution.save!
      results = contribution.process

      expect(results).to be true
      expect(alice.slices_of_pie.to_f).to eql(5 * alice.hourly_rate)
      expect(bob.slices_of_pie.to_f).to eql(5 * bob.hourly_rate)
    end

    it '/heypie-group @alice 10 @bob 5' do
      alice = Grunt.create!(slack_user_id: "alice-id", base_salary: 99_001)
      bob = Grunt.create!(slack_user_id: 'bob-id', base_salary: 7_333)

      mock_client = instance_double('SlackClient')
      controller.client = mock_client
      stubbed = Slack::Messages::Message.new({
          members: [
            {
              id: "alice-id",
              name: "alice"
            },
            {
              id: "bob-id",
              name: "bob"
            }
          ]
      })
      allow(mock_client).to receive(:users_list).and_return(stubbed)
      allow(mock_client).to receive(:chat_postMessage).and_return(nil)

      command = from_slack('/heypie-group @alice 10.27 @bob 7.77')
        .merge({ "channel_id": "9999", "user_id": "alice-id"})

      post :heypie_group_command, params: command

      contribution = Contribution.last
      contribution.voters = []
      contribution.save!
      results = contribution.process

      expect(results).to be true
      expect(alice.slices_of_pie.to_f).to be_within(1).of(10.27 * alice.hourly_rate)
      expect(bob.slices_of_pie.to_f).to be_within(1).of(7.77 * bob.hourly_rate)
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
      Grunt.create!(slack_user_id: "Alice")

      client = instance_double('Slack::Client')
      controller.client = client
      params = {}

      post :dialog_submission, params: params

      expect(response).to have_http_status :bad_request
    end

    it 'returns 200 OK if user is found' do
      alice = Grunt.create!(slack_user_id: "Alice")
      Grunt.create!(slack_user_id: "Submitter")

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

      contribution = Contribution.last
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
      alice = Grunt.new(slack_user_id: "Alice")
      bob = Grunt.new(slack_user_id: "Bob")  # is the voter
      contribution = Contribution.new(
        submitter: Grunt.new,
        voters: [alice, bob],
        ts: "my-ts"
      )
      mock_client = instance_double("NullClient").as_null_object
      controller.client = mock_client

      contribution.contribute_hours({
        bob => 10,
        alice => 5
      })

      contribution.save!

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

      expect(contribution.processed).to be false
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
      Contribution.create!(submitter: Grunt.create!(slack_user_id: 'submitter'))

      post :events, params: params

      expect(Contribution.last.ts).to eql 'some-ts'
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

