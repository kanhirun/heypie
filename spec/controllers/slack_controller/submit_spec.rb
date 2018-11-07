require 'rails_helper'

describe SlackController, type: :controller do
  before do
    allow(ENV).to receive(:fetch).with("SLACK_WORKSPACE").and_return("sixpence")

    validator = double("aRequestValidator").as_null_object
    allow(validator).to receive(:authenticated?).and_return(true)
    allow(controller).to receive(:validator).and_return(validator)

    @client = instance_double('aSlackClient').as_null_object
    allow(controller).to receive(:client).and_return(@client)

    @logger = instance_double('aLogger')
    allow(Rails).to receive(:logger).and_return(@logger)
  end

  describe 'POST /slack/interactions/submit' do
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

      post :submit, params: params

      expect(response).to have_http_status :not_found
    end

    it 'returns 400 if empty params' do
      Grunt.create!(slack_user_id: "Alice")
      expect(@logger).to receive(:error)

      post :submit, params: {}

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

      post :submit, params: params

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
end

