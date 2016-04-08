# Cinch-LoveLetter - Love Letter plugin

[![Build Status](https://travis-ci.org/petertseng/cinch-loveletter.svg?branch=master)](https://travis-ci.org/petertseng/cinch-loveletter)

## Description

This is an IRC bot using [cinch](https://github.com/cinchrb/cinch) and [cinch-game-bot](https://github.com/petertseng/cinch-game-bot) to allow play-by-IRC of [Love Letter](http://boardgamegeek.com/boardgame/129622/love-letter)

## Setup

You'll need a recent version of [Ruby](https://www.ruby-lang.org/).
Ruby 2.1 or newer is required because of the `Array#to_h` method.
The [build status](https://travis-ci.org/petertseng/cinch-loveletter) will confirm compatibility with various Ruby versions.
Note that [2.1 is in security maintenance mode](https://www.ruby-lang.org/en/news/2016/02/24/support-plan-of-ruby-2-0-0-and-2-1/), so it would be better to use a later version.

You'll need to install the required gems, which can be done automatically via `bundle install`, or manually by reading the `Gemfile` and using `gem install` on each gem listed.

## Usage

Given that you have performed the requisite setup, the minimal code to get a working bot might resemble:

```ruby
require 'cinch'
require 'cinch/plugins/loveletter'

bot = Cinch::Bot.new do
  configure do |c|
    c.nick            = 'LoveLetterBot'
    c.server          = 'irc.example.org'
    c.channels        = ['#playloveletter']
    c.plugins.plugins = [Cinch::Plugins::LoveLetter]
    c.plugins.options[Cinch::Plugins::LoveLetter] = {
      channels: ['#playloveletter'],
      settings: 'loveletter-settings.yaml',
    }
  end
end

bot.start
```

## Notes

Unfortunately, unlike the other game bots, this repo has both the game logic and bot in a single repo.
It would be super easy to separate them since they're in separate directories.
The code was written too long ago and there's too little interest in this to justify that effort though.

In general, this code is not regularly maintained.
The tests were last known to pass on Cinch 2.3.1 and cinch-game-bot f689a0c2ab8d.
A quick run through of a game was performed as well to ensure that the game was at least functional.
Compatibility with later versions of either gem is not guaranteed.
