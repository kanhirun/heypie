require 'rails_helper'

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
