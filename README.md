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

## Notes

Unfortunately, unlike the other game bots, this repo has both the game logic and bot in a single repo.
It would be super easy to separate them since they're in separate directories.
The code was written too long ago and there's too little interest in this to justify that effort though.

In general, this code is not regularly maintained.
The tests were last known to pass on Cinch 2.3.1 and cinch-game-bot f689a0c2ab8d.
A quick run through of a game was performed as well to ensure that the game was at least functional.
Compatibility with later versions of either gem is not guaranteed.
