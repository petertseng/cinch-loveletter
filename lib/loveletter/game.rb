# Copyright 2014 Peter Tseng
#
# This file is part of the Love Letter plugin for Cinch.
# This program is released under the MIT License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the MIT License for more details.
#
# You should have received a copy of the MIT License along with this program.
# If not, see <http://opensource.org/licenses/MIT>

require 'set'

require 'loveletter/card'
require 'loveletter/player'

module LoveLetter; class Game
  BASE_DECK = [
    [Card.new(1)] * 5,
    [Card.new(2)] * 2,
    [Card.new(3)] * 2,
    [Card.new(4)] * 2,
    [Card.new(5)] * 2,
    [Card.new(6)] * 1,
    [Card.new(7)] * 1,
    [Card.new(8)] * 1,
  ].flatten.freeze

  NEED_TARGET = Set.new([1, 2, 3, 5, 6])

  attr_reader :channel_name
  attr_reader :round
  attr_reader :in_progress

  attr_accessor :goal_score
  attr_accessor :minister_death

  alias :in_progress? :in_progress

  def initialize(channel_name)
    @channel_name = channel_name

    @goal_score = 1
    @minister_death = false

    reset
  end

  def reset
    @in_progress = false

    @players = {}
  end

  def start_game(rigged_deck: nil, rigged_order: nil)
    @in_progress = true
    @round = 0

    @player_order = @players.values
    @player_order.shuffle!

    @round_winners = []
    @game_winner = nil

    start_round(rigged_deck: rigged_deck, rigged_order: rigged_order)
  end

  def start_round(rigged_deck: nil, rigged_order: nil)
    @round += 1

    if rigged_deck
      @deck = rigged_deck.map { |i| Card.new(i) }
    else
      @deck = BASE_DECK.shuffle
    end

    @facedown_card = @deck.shift
    @faceup_cards = []

    if rigged_order
      @round_player_order = rigged_order.map { |p| @players[p] }
    else
      @round_player_order = @player_order.dup

      # In round 1, first player is random
      # In subsequent rounds, first player is previous winner
      if @round_winners[-1]
        until @round_player_order[0] == @round_winners[-1]
          # Rotate both so that player_order also has the order for this round
          @round_player_order.rotate!
          @player_order.rotate!
        end
      end
    end

    3.times { @faceup_cards << @deck.shift } if size == 2

    @round_player_order.each { |p|
      p.start_round
      p.add_to_hand(@deck.shift)
    }
  end

  def dehighlight_nick(nickname)
    nickname.scan(/.{2}|.+/).join(8203.chr('UTF-8'))
  end

  def player_history
    @player_order.map { |p|
      nick = dehighlight_nick(p.name)
      cards = p.discards.map(&:to_s).join(', ')
      "#{nick}#{' (OUT!)' unless p.alive?}: #{cards}"
    }.join("\n")
  end

  # If someone dies to minister, returns [player, hand] else [nil, nil]
  def draw
    player = @round_player_order[0]
    raise 'draw called when deck empty' if @deck.empty?
    player.add_to_hand(@deck.shift)

    player.protected = false

    # Player died due to having 7
    if @minister_death && player.ministered?
      bad_hand = player.hand.map(&:to_s).join(' and ')

      kill_player(player)

      if @game_winner
        # This led to a game winner. Do nothing else.
      elsif @round_winners.size >= @round
        # We found a round winner by sole survivor.
      elsif @deck.empty?
        # Deck is empty. Time to compare cards.
        compare_cards
      else
        # Move on to the next player's turn
        draw
      end
      return [player.name, bad_hand]
    end

    [nil, nil]
  end

  def remaining_players
    @round_player_order.map { |p| [p, p.card] }
  end

  def player_order
    @player_order.dup
  end

  def size
    @players.size
  end

  def full?
    @players.size == 4
  end

  def players
    @players.keys
  end

  def has_player?(p)
    @players.include?(p.downcase)
  end

  def add_player(p)
    @players[p.downcase] = Player.new(p, @channel_name)
  end

  def remove_player(p)
    @players.delete(p.downcase)
  end

  def active_player_name
    @round_player_order[0].name
  end

  def alive?(p)
    @players[p.downcase] && @players[p.downcase].alive?
  end

  def round_winner(round)
    (winner = @round_winners[round - 1]) && winner.name
  end

  def game_winner
    @game_winner && @game_winner.name
  end

  def faceup_cards
    @faceup_cards.dup
  end

  def deck_size
    @deck.size
  end

  # Returns [success, public text, private text]
  def play_card(player_name, card, args)
    unless player_name == active_player_name
      return [false, nil, {player_name => 'You must wait your turn.'}]
    end
    player = resolve_name(player_name)

    id = card.to_i
    index = player.hand.index { |c| c.id == id }

    if player.hand.size == 1
      raise "#{player_name} played before drawing"
    end

    if !index
      return [false, nil, {player_name => "You do not have a #{card}"}]
    end

    # Since there will only be two cards in hand, index will either be 0 or 1
    other_index = 1 - index

    if player.ministered? && id != 7
      seven = Card.new(7)
      msg = "You MUST play your #{seven}: #{seven.usage}."
      return [false, nil, {player_name => msg}]
    end

    pubtext = nil
    privtext = {}

    args = args ? args.split : []

    if NEED_TARGET.include?(id)
      if args.empty?
        msg = "You must specify a target for #{Card.name(id)}."
        return [false, nil, {player_name => msg}]
      end

      target = resolve_name(args[0])
      unless target
        msg = args[0] + ' is not a valid target.'
        return [false, nil, {player_name => msg}]
      end

      if target == player && id != 5
        msg = "You can only self-target with a #{Card.name(5)}"
        return [false, nil, {player_name => msg}]
      end
    end

    prefix = "#{player} plays #{Card.name(id)}"
    case id
    when 1
      # Guess
      guess = args[1] ? args[1].to_i : 0
      if 2 > guess || guess > 8
        msg = 'You must guess a number between 2 and 8.'
        return [false, nil, {player_name => msg}]
      end
      prefix << " to see if #{target} has #{Card.name(guess)}. "

      if target.protected?
        pubtext = prefix + "But #{target} is protected!"
      elsif target.card.id == guess
        pubtext = prefix + "#{target} does and is out of the round!"
        kill_player(target)
      else
        pubtext = prefix + "But #{target} does not."
      end

    when 2
      # Peek at card
      pubtext = prefix + " to see #{target}'s card."
      if target.protected?
        pubtext << " But #{target} is protected!"
      else
        privtext[player_name] = "#{target} has a #{target.card}."
        privtext[target.name] = "You showed #{player} your #{target.card}."
      end

    when 3
      # Battle!
      my_card = player.hand[other_index]

      prefix << " to battle with #{target}. "
      if target.protected?
        pubtext = prefix + "But #{target} is protected!"
      elsif target.card.id < my_card.id
        pubtext = prefix + "#{target}'s #{target.card} is clearly " +
          "inferior, so #{target} is out of the round!"
        kill_player(target)
      elsif target.card.id > my_card.id
        pubtext = prefix + "#{player}'s #{my_card} is clearly " +
          "inferior, so #{player} is out of the round!"
        kill_player(player)
      else
        pubtext = prefix + 'It was a great battle, but the match was ' +
          'inconclusive.'
      end

    when 4
      # Protect
      player.protected = true
      pubtext = prefix + ". #{player} is protected for one turn!"

    when 5
      # Force discard
      if deck_size > 0
        new_card = @deck.shift
        source = 'a card from the deck'
      else
        new_card = @facedown_card
        source = 'the facedown card'
      end

      if target == player
        replace_index = other_index
        old_card = player.hand[replace_index]
      else
        replace_index = 0
        old_card = target.card
      end

      pubtext = prefix + " to make #{target} discard."

      if target.protected?
        pubtext << " But #{target} is protected!"
      elsif old_card.id == 8
        kill_player(target)
        pubtext << " Because #{target} discarded a #{old_card}, " +
          "#{target} is out of the round!"
      else
        pubtext << " #{target} discards #{old_card} then picks up #{source}."
        target.discard_and_replace(new_card, replace_index)
        privtext[target.name] = "#{player} made you discard your " +
          "#{old_card}. Your new card is #{new_card}."
      end

    when 6
      # Trade hands
      pubtext = prefix + " to trade hands with #{target}."
      if target.protected?
        pubtext << " But #{target} is protected!"
      else
        my_card, their_card = player.trade_hand_with(target, other_index)
        privtext[player_name] =
          "You traded with #{target} and got a #{my_card}."
        privtext[target.name] =
          "#{player} traded with you giving you a #{their_card}."
      end

    when 7
      pubtext = prefix + '.'

    when 8
      # Die!
      pubtext = prefix + ". #{player_name} is out of the round!"
      kill_player(player)
    end

    if player.alive?
      # If I'm still alive, play my card.
      # If I died, I've already discarded my cards so don't play.
      player.play_card_at(index)

      # Let next player take turn.
      # If I'm alive, that means I must rotate to the back.
      # If I'm dead, next player is already in position, so no rotate.
      @round_player_order.rotate!
    end

    compare_cards if deck_size == 0

    [true, pubtext, privtext]
  end

  def hand(player_name)
    @players[player_name.downcase].hand
  end

  def legal_plays(player_name)
    p = @players[player_name.downcase]
    return [Card.new(7)] if p.ministered?
    p.hand.uniq(&:id)
  end

  private

  def resolve_name(name)
    #TODO do some spellcheck
    if (p = @players[name.downcase]) && p.alive?
      p
    else
      nil
    end
  end

  def win_round(winner)
    @round_winners << winner
    winner.win_round
    @game_winner = winner if winner.rounds_won >= @goal_score
  end

  def compare_cards
    rank = @round_player_order.map { |p|
      [p.card.id, p.discards.map(&:id).inject(0, :+), p]
    }.sort
    win_round(rank[-1][2])
  end

  def check_sole_survivor
    return if @round_player_order.size != 1

    win_round(@round_player_order[0])
  end

  def kill_player(player)
    player.die
    @round_player_order.delete(player)
    check_sole_survivor
  end
end; end
