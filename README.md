# Cinch-LoveLetter - Love Letter plugin

## Description

This is an IRC bot using [cinch](https://github.com/cinchrb/cinch) and [cinch-game-bot](https://github.com/petertseng/cinch-game-bot) to allow play-by-IRC of [Love Letter](http://boardgamegeek.com/boardgame/129622/love-letter)

## Usage

Here's an example of what your *bot.rb* might look like:

    require 'cinch'
    require 'cinch/plugins/loveletter'

    bot = Cinch::Bot.new do

      configure do |c|
        c.nick            = "LoveLetterBot"
        c.server          = "irc.freenode.org"
        c.channels        = ["#playloveletter"]
        c.verbose         = true
        c.plugins.plugins = [
          Cinch::Plugins::LoveLetter,
        ]
        c.plugins.options[Cinch::Plugins::LoveLetter] = {
          :channels  => ["#playloveletter"],
          :settings  => 'loveletter-settings.yaml',
        }
      end

    end

    bot.start
