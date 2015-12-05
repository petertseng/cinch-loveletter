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

require 'cinch'
require 'cinch/plugins/game_bot'
require 'loveletter/game'

module Cinch; module Plugins; class LoveLetter < GameBot
  include Cinch::Plugin

  match(/help/i, method: :halp)

  match(/settings(?:\s+(##?\w+))?$/i, method: :get_settings)
  match(/settings(?:\s+(##?\w+))? (.+)$/i, method: :set_settings)

  match(/players/i, method: :player_history)

  match(/play\s+(\w+)(?:\s+(.*))?/i, method: :play_card)

  add_common_commands

  def halp(m)
    m.reply('!join, !leave, !start, !play: Do the obvious.')
    m.reply('!settings [args]: Without arguments, displays current settings. With arguments (goalX, 7death, 7discard) changes settings.')
    m.reply('!players: Shows history of cards played this round.')
  end

  #--------------------------------------------------------------------------------
  # Implementing classes should override these
  #--------------------------------------------------------------------------------

  def game_class
    ::LoveLetter::Game
  end

  def do_start_game(m, game, players, options)
    game.start_game(players.map(&:user))
    channel = Channel(game.channel_name)
    channel.send('The game has started. Settings: ' + game_settings(game))
    channel.send("Turn order: #{game.player_order.join(', ')}")

    step(game, channel, -1)
    true
  end

  def do_reset_game(game)
    # TODO: Show what cards everyone had?
  end

  def do_replace_user(game, replaced_user, replacing_user)
    # Love Letter doesn't need to do anything.
  end

  #--------------------------------------------------------------------------------
  # Game
  #--------------------------------------------------------------------------------

  GOAL_REGEX = /goal(\d+)/

  def game_settings(game)
    minister_result = game.minister_death ? 'knockout' : 'discard'
    "Play to #{game.goal_score} points. " +
    "12+ with 7 in hand causes #{minister_result}."
  end

  def get_settings(m, channel_name = nil)
    game = self.game_of(m, channel_name, ['see settings', '!settings'])
    return unless game

    m.reply('Current game settings: ' + game_settings(game))
  end

  def set_settings(m, channel_name = nil, args = '')
    game = self.game_of(m, channel_name, ['change settings', '!settings'])
    return unless game

    if game.started?
      m.reply('Game is already in progress.', true)
      return
    end

    unknown_arg = false
    args.strip.split.each { |arg|
      if match = GOAL_REGEX.match(arg)
        game.goal_score = match[1].to_i
      elsif arg == '7death'
        game.minister_death = true
      elsif arg == '7discard'
        game.minister_death = false
      else
        unknown_arg = true
      end
    }

    channel = Channel(game.channel_name)
    same_origin = m.channel == channel
    m.reply('Unrecognized settings. ' +
            'Valid settings: goalN, 7death, 7discard') if unknown_arg
    prefix = same_origin ?
      'The game has been changed to: ' :
      (m.user.name + ' has changed the game to: ')
    channel.send(prefix + game_settings(game))
  end

  def player_history(m)
    game = self.game_of(m)
    return unless game && game.started? && game.users.include?(m.user)

    m.reply(game.player_history)
  end

  def play_card(m, card, args)
    game = self.game_of(m)
    return unless game && game.started? && game.users.include?(m.user)

    success, pubtext, privtext = game.play_card(m.user, card, args)

    channel = Channel(game.channel_name)
    channel.send(pubtext) if pubtext
    privtext.each { |p, pm| User(p).send(pm) } if privtext
    step(game, channel, game.round) if success
  end

  def step(game, channel, initial_round)
    expected_round = initial_round
    first = true

    # Ensure that we cause a player to draw at least once (`first` flag)
    # The drawing player may die to minister.
    # This may cause us to advance a round, in which case we draw again.
    # Or we may have a winner, in which case we break out of this loop.
    while !game.game_winner && (first || expected_round != game.round)
      first = false

      if expected_round != game.round
        announce_new_round(game, channel)
        expected_round = game.round
      end

      if !game.round_winner(game.round)
        victim, hand = game.draw
        if victim
          msg = "#{victim} draws and is out due to having #{hand} in hand!"
          channel.send(msg)
        end
      end

      # This is NOT an else! game.draw may cause a winner to appear.
      # In such cases, we want to announce the winner.
      if game.round_winner(game.round)
        LoveLetter.announce_round_winner(game, channel)
      end
    end

    if game.game_winner
      # If first == true, we have a game winner,
      # but never announced the round winner in the above while loop.
      # Do so now.
      LoveLetter.announce_round_winner(game, channel) if first

      channel.send("Game over! #{game.game_winner} is the winner!")
      self.start_new_game(game)
    else
      prompt_active_player(game, channel)
    end
  end

  def self.announce_round_winner(game, channel)
    winner = game.round_winner(game.round)

    remain = game.remaining_players.map { |p, c| "#{p} (#{c.id})" }.join(', ')

    channel.send("The remaining players: #{remain}")
    channel.send("#{winner} is the winner of round #{game.round}!")
    game.start_round
  end

  def announce_new_round(game, channel)
    channel.send("----- Round #{game.round} -----")
    channel.send('One card has been set aside, face down.')
    faceups = game.faceup_cards
    if faceups.size > 0
      ups = faceups.map(&:to_s).join(', ')
      channel.send('Additionally, these cards have been set aside: ' +
                   ups + '.')
    end

    # Tell players of their initial hand.
    game.users.each { |u|
      card = game.hand(u)[0]
      u.send("Your first card for round #{game.round} is: #{card}.")
    }
  end

  def prompt_active_player(game, channel)
    active = game.active_user
    channel.send("#{active} draws a card. " +
                 "#{game.deck_size} cards remain in the deck.")
    hand = game.hand(active).map(&:short_help).join(' and ')
    plays = game.legal_plays(active)
    options = plays.map(&:usage).join(' or ')
    active.send("It's your turn and your hand is #{hand}.")
    active.send('To play a card: ' + options)
  end
end; end; end
