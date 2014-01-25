# Cinch-LoveLetter - Love Letter plugin

## Description

This is a Cinch plugin to enable your bot to moderate Love Letter.

http://boardgamegeek.com/boardgame/129622/love-letter

## Usage

Here's an example of what your *bot.rb* might look like:

    require 'cinch'
    require './cinch-loveletter/lib/cinch/plugins/loveletter'

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
          :channels     => ["#playloveletter"],
          :allowed_idle => 900,
        }
      end

    end

    bot.start
