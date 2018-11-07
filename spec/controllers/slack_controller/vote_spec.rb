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

      post :vote, params: { payload: params }

      alice.reload

      expect(contribution.processed).to be false
      expect(alice.slices_of_pie).to eql 0
      expect(response).to have_http_status 204
    end

    it 'accepts a vote' do
    end
  end
end
