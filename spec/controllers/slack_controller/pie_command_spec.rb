require 'rails_helper'

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
    context "without args" do
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

    context "with args" do
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

      xit 'also opens a dialog' do
        Grunt.create!(slack_user_id: "alice-id")
        dialog = {
          "callback_id": "ryde-46e2b0",
          "title": "Hey! Ready to request?", # 24 char
          "submit_label": "Yeah_I_am!",  # one word contraint
          "elements": [
            {
              "label": "Describe it for me.",
              "type": "textarea",
              "name": "contribution_description",
              "hint": "Provide additional information if needed."
            }
          ]
        }
        expect(@client).to receive(:dialog_open).with({ trigger_id: "some-trigger-id", dialog: dialog })

        command = from_slack('/pie @alice 22').merge({ "channel_id": "9999", "user_id": "alice-id"})
        post :pie_command, params: command

        # todo: expect(response).to have_http_status :ok
        expect(response).to have_http_status :no_content
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
end
