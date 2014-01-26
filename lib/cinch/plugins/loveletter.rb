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
require 'set'

require 'loveletter/game'

module Cinch; module Plugins; class LoveLetter
  include Cinch::Plugin

  match(/help/i, method: :halp)

  match(/join(?:\s+(#\w+))?/i, method: :join)
  match(/leave(?:\s+(#\w+))?/i, method: :leave)

  match(/settings(?:\s+(#\w+))?\s+(.*)/i, method: :settings)

  match(/start(?:\s+(#\w+))?/i, method: :start_game)
  match(/reset(?:\s+(#\w+))?/i, method: :reset_game)

  match(/players(?:\s+(#\w+))?/i, method: :player_history)

  match(/play(?:\s+(#\w+))?\s+(\w+)(?:\s+(.*))?/i, method: :play_card)

  listen_to :leaving, method: :remove_if_not_started

  def halp(m)
    m.reply("!join, !leave, !start, !reset, !play, !settings")
    m.reply("Too lazy to write real help")
  end

  def initialize(*args)
    super

    # Hash of channel name (string) => game
    @games = {}
    # Hash of channel name (string) => timer
    @idle_timers = {}
    config[:channels].each { |c|
      @games[c] = ::LoveLetter::Game.new(c)
      @idle_timers[c] = start_idle_timer(c, @games[c])
    }
    @idle_timer_length = config[:allowed_idle]

    # Hash of player name (string) => set of games
    @players = Hash.new { |h, c| h[c] = Set.new }
  end

  def start_idle_timer(channel_name, game)
    Timer(300) {
      game.players.each { |pn|
        user = User(pn)
        user.refresh
        next unless user.idle > @idle_timer_length

        channel = Channel(channel_name)
        remove_from_game(channel, game, user)
        user.send("You have been removed from the #{channel_name} game " +
                  "due to inactivity.")
      }
    }
  end

  def remove_from_game(channel, game, user)
    game.remove_player(user.name)
    channel.send("#{user.name} has left the game: #{game.size} players.")
    @players[user.name].delete(game)
  end

  def remove_if_not_started(m, user)
    game = @games[m.channel.name]
    return unless game
    return if game.in_progress?

    remove_from_game(m.channel, game, user)
  end

  def join(m, channel_name)
    channel = channel_name ? Channel(channel_name) : m.channel

    unless channel
      m.reply('To join a game via PM you must specify the channel: ' +
              '!join #channel')
      return
    end

    unless channel.has_user?(m.user)
      m.reply("You must be in #{channel.name} to join the game.")
      return
    end

    game = @games[channel.name]
    unless game
      m.reply(channel.name + 'is not a valid channel to join.', true)
      return
    end

    if game.has_player?(m.user.name)
      m.reply('You are already in the game.', true)
      return
    end

    if game.in_progress?
      m.reply('The game has already started.', true)
      return
    end

    if game.full?
      m.reply('The game is full.', true)
      return
    end

    game.add_player(m.user.name)
    msg = "#{m.user.name} has joined the game: #{game.size} players."
    channel.send(msg)
    @players[m.user.name].add(game)
  end

  def leave(m, channel_name)
    channel = channel_name ? Channel(channel_name) : m.channel
    game = nil

    unless channel
      # If PM and player is only in one game, remove them from that game
      if @players[m.user.name].size == 1
        game = @players[m.user.name].to_a[0]
        channel = Channel(game.channel_name)
      else
        names = @players[m.user.name].to_a.map(&:channel_name)
        msg = "Since you are in multiple games (#{names.join(', ')}), " +
              'to leave via PM you must specify which game to leave: ' +
              '!leave #channel'
        m.reply(msg)
        return
      end
    end

    game ||= @games[channel.name]
    unless game
      m.reply(channel.name + ' is not a valid channel to leave.', true)
      return
    end

    unless game.has_player?(m.user.name)
      m.reply('You were not in the game anyway.', true)
      return
    end

    if game.in_progress?
      m.reply('Cannot abandon a game in progress.', true)
      return
    end

    remove_from_game(channel, game, m.user)
  end

  GOAL_REGEX = /goal(\d+)/

  def game_settings(game)
    minister_result = game.minister_death ? 'knockout' : 'discard'
    "Play to #{game.goal_score} points. " +
    "12+ with 7 in hand causes #{minister_result}."
  end

  def settings(m, channel_name, args)
    channel = channel_name ? Channel(channel_name) : m.channel

    unless channel
      m.reply('To change settings via PM you must specify the channel: ' +
              '!settings #channel args')
      return
    end

    game = @games[channel.name]
    unless game
      m.reply(channel.name + ' is not a valid channel to set.', true)
      return
    end

    if game.in_progress?
      m.reply('Game is already in progress.', true)
      return
    end

    args = args ? args.split : []

    if args.empty?
      m.reply('Current game settings: ' + game_settings(game))
    else
      unknown_arg = false
      args.each { |arg|
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

      same_origin = m.channel == channel
      m.reply('Unrecognized settings. ' +
              'Valid settings: goalN, 7death, 7discard') if unknown_arg
      prefix = same_origin ?
        'The game has been changed to: ' :
        (m.user.name + ' has changed the game to: ')
      channel.send(prefix + game_settings(game))
    end
  end

  def start_game(m, channel_name)
    channel = channel_name ? Channel(channel_name) : m.channel

    unless channel
      m.reply('To start a game via PM you must specify the channel: ' +
              '!start #channel')
      return
    end

    game = @games[channel.name]
    unless game
      m.reply(channel.name + ' is not a valid channel to start.', true)
      return
    end

    unless game.has_player?(m.user.name)
      m.reply('You are not in the game.', true)
      return
    end

    if game.in_progress?
      m.reply('Game is already in progress.', true)
      return
    end

    if game.size == 1
      m.reply('Cannot play the game alone.', true)
      return
    end

    game.start_game
    @idle_timers[channel.name].stop
    channel.send('The game has started. Settings: ' + game_settings(game))
    channel.send("Turn order: #{game.player_order.join(', ')}")

    step(game, channel, -1)
  end

  def reset_game(m, channel_name)
    channel = channel_name ? Channel(channel_name) : m.channel

    unless channel
      m.reply('To start a game via PM you must specify the channel: ' +
              '!reset #channel')
      return
    end

    game = @games[channel.name]
    unless game
      m.reply(channel.name + ' is not a valid channel to reset.', true)
      return
    end

    unless game.has_player?(m.user.name)
      m.reply('You are not in the game.', true)
      return
    end

    game.players.each { |p| @players[p].delete(game) }
    game.reset
    @idle_timers[channel.name].start
    channel.send("The game has been reset.")
  end

  def player_history(m, channel_name)
    channel = channel_name ? Channel(channel_name) : m.channel
    game = nil

    unless channel
      # If PM and player is only in one game, play in that game
      if @players[m.user.name].size == 1
        game = @players[m.user.name].to_a[0]
        channel = Channel(game.channel_name)
      else
        names = @players[m.user.name].to_a.map(&:channel_name)
        msg = "Since you are in multiple games (#{names.join(', ')}), " +
              'to play via PM you must specify which game to play: ' +
              '!play #channel card args'
        m.reply(msg)
        return
      end
    end

    game ||= @games[channel.name]
    return unless game

    unless game.has_player?(m.user.name)
      m.reply('You are not in the game.', true)
      return
    end

    unless game.in_progress?
      m.reply('The game has not started yet.', true)
      return
    end

    m.reply(game.player_history)
  end

  def play_card(m, channel_name, card, args)
    channel = channel_name ? Channel(channel_name) : m.channel
    game = nil

    unless channel
      # If PM and player is only in one game, play in that game
      if @players[m.user.name].size == 1
        game = @players[m.user.name].to_a[0]
        channel = Channel(game.channel_name)
      else
        names = @players[m.user.name].to_a.map(&:channel_name)
        msg = "Since you are in multiple games (#{names.join(', ')}), " +
              'to play via PM you must specify which game to play: ' +
              '!play #channel card args'
        m.reply(msg)
        return
      end
    end

    game ||= @games[channel.name]
    return unless game

    unless game.has_player?(m.user.name)
      m.reply('You are not in the game.', true)
      return
    end

    unless game.in_progress?
      m.reply('The game has not started yet.', true)
      return
    end

    success, pubtext, privtext = game.play_card(m.user.name, card, args)

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
      game.players.each { |p| @players[p].delete(game) }
      game.reset
      @idle_timers[channel.name].start
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
    game.players.each { |p|
      card = game.hand(p)[0]
      User(p).send("Your first card for round #{game.round} is: #{card}.")
    }
  end

  def prompt_active_player(game, channel)
    active = game.active_player_name
    channel.send("#{active} draws a card. " +
                 "#{game.deck_size} cards remain in the deck.")
    hand = game.hand(active).map(&:short_help).join(' and ')
    plays = game.legal_plays(active)
    options = plays.map(&:usage).join(' or ')
    User(active).send("It's your turn and your hand is #{hand}.")
    User(active).send('To play a card: ' + options)
  end
end; end; end
