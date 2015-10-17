require 'cinch/test'
require 'cinch/plugins/loveletter'

class MessageReceiver
  attr_accessor :messages

  def initialize
    @messages = []
  end

  def send(m)
    @messages << m
  end
end

def get_replies_text(m)
  get_replies(m).map(&:text)
end

describe Cinch::Plugins::LoveLetter do
  include Cinch::Test

  let(:channel1) { '#test' }

  let(:opts) {{
    :channels => [channel1],
    :allowed_idle => 300,
  }}
  let(:bot) {
    b = make_bot(described_class, opts) { |c|
      self.loggers.first.level = :warn
    }
    # No, c.nick = 'testbot' doesn't work because... isupport?
    allow(b).to receive(:nick).and_return('testbot')
    b
  }
  let(:plugin) { bot.plugins.first }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  context 'while in a game' do
    let(:chan) { MessageReceiver.new }
    let(:player1) { 'test1' }
    let(:player2) { 'test2' }
    let(:user1) { MessageReceiver.new }
    let(:user2) { MessageReceiver.new }
    let(:players) { {
      player1 => user1,
      player2 => user2,
    }}

    before :each do
      allow(plugin).to receive(:Channel).with(channel1).and_return(chan)
      allow(plugin).to receive(:User).with(player1).and_return(user1)
      allow(plugin).to receive(:User).with(player2).and_return(user2)

      allow(chan).to receive(:has_user?) { |u| players.keys.include?(u.nick) }
      allow(chan).to receive(:name).and_return(channel1)

      get_replies(make_message(bot, "!join #{channel1}", nick: player1))
      get_replies(make_message(bot, "!join #{channel1}", nick: player2))
      get_replies(make_message(bot, "!start #{channel1}", nick: player1))
    end

    it 'allows the !players command' do
      replies = get_replies_text(make_message(bot, "!players", nick: player1, channel: channel1))
      expect(replies.size).to be == 1
    end
  end
end
