require 'rails_helper'


# disable for now until better solution around testing message verifier
describe SlackController, type: :controller do
  before :each do
    allow(ENV).to receive(:fetch).with("SLACK_WORKSPACE").and_return("sixpence")

    validator = double("aRequestValidator").as_null_object
    allow(validator).to receive(:authenticated?).and_return(true)
    allow(controller).to receive(:validator).and_return(validator)

    @client = instance_double('aSlackClient').as_null_object
    allow(controller).to receive(:client).and_return(@client)

    @logger = instance_double('aLogger')
    allow(Rails).to receive(:logger).and_return(@logger)
  end

  describe 'POST /slack/commands/pie' do
    context "without arguments" do
      it 'opens a dialog' do
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
        expect(@client).to receive(:dialog_open).with({ trigger_id: "some-trigger-id", dialog: dialog })

        post :pie_command, params: { "command": '/heypie', "text": "", "trigger_id": "some-trigger-id" }

        # todo: expect(response).to have_http_status :ok
        expect(response).to have_http_status :no_content
      end

      describe 'errors' do
        before do
          allow(@client).to receive(:dialog_open).with(anything()) do
            raise Slack::Web::Api::Errors::SlackError.new("timeout")
          end
        end

        it "returns 504 when too slow for Slack" do
          post :pie_command, params: {
            "text": "",
            "trigger_id": "99999999"
          }

          expect(response).to have_http_status 504
        end
      end
    end

    context "with arguments" do
      before do
        users = Slack::Messages::Message.new({
          members: [
            { id: "alice-id", name: "alice" },
            { id: "bob-id", name: "bob" }
          ]
        })

        allow(@client).to receive(:users_list).and_return(users)
        allow(@client).to receive(:chat_postMessage).and_return(nil)
      end

      it '/pie @alice 22' do
        alice = Grunt.create!(slack_user_id: "alice-id")
        command = from_slack('/pie @alice 22').merge({ "channel_id": "9999", "user_id": "alice-id"})

        post :pie_command, params: command

        contribution = Contribution.last

        contribution.voters = []
        contribution.save!
        results = contribution.process

        expect(results).to be true
        expect(alice.slices_of_pie.to_f).to eql(22 * alice.hourly_rate)
      end

      it '/heypie-group @alice @bob 5.0' do
        alice = Grunt.create!(slack_user_id: "alice-id", base_salary: 10_000)
        bob = Grunt.create!(slack_user_id: 'bob-id', base_salary: 7_000)
        command = from_slack('/heypie-group @alice @bob 5.0').merge({ "channel_id": "9999", "user_id": "alice-id"})

        post :pie_command, params: command

        contribution = Contribution.last
        contribution.voters = []
        contribution.save!
        results = contribution.process

        expect(results).to be true
        expect(alice.slices_of_pie.to_f).to eql(5 * alice.hourly_rate)
        expect(bob.slices_of_pie.to_f).to eql(5 * bob.hourly_rate)
      end

      it '/pie @alice 10 @bob 5' do
        alice = Grunt.create!(slack_user_id: "alice-id", base_salary: 99_001)
        bob = Grunt.create!(slack_user_id: 'bob-id', base_salary: 7_333)
        command = from_slack('/heypie-group @alice 10.27 @bob 7.77').merge({ "channel_id": "9999", "user_id": "alice-id"})

        post :pie_command, params: command

        contribution = Contribution.last
        contribution.voters = []
        contribution.save!
        results = contribution.process

        expect(results).to be true
        expect(alice.slices_of_pie.to_f).to be_within(1).of(10.27 * alice.hourly_rate)
        expect(bob.slices_of_pie.to_f).to be_within(1).of(7.77 * bob.hourly_rate)
      end

      xit '/pie @here 10' do; end
      xit '/pie @alice @alice 10 @alice 5' do; end
    end
  end

  describe 'POST /slack/interactions/dialog_submission' do
    it "returns 404 when user doesn't exist" do
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
      expect(@logger).to receive(:warn)

      post :dialog_submission, params: params

      expect(response).to have_http_status :not_found
    end

    it 'returns 400 if empty params' do
      Grunt.create!(slack_user_id: "Alice")
      expect(@logger).to receive(:error)

      post :dialog_submission, params: {}

      expect(response).to have_http_status :bad_request
    end

    it 'returns 200 if user is found' do
      alice = Grunt.create!(slack_user_id: "Alice")
      Grunt.create!(slack_user_id: "Submitter")
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

describe SlackController, type: :controller do
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

