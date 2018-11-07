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
