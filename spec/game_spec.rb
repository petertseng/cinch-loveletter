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

require 'spec_helper'

require 'loveletter/game'

RSpec.describe LoveLetter::Game do
  Card = LoveLetter::Card

  before :each do
    @game = LoveLetter::Game.new('testchannel')
    @game.goal_score = 1
  end

  # ===== General tests =====

  it 'forbids playing a card not in hand' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 2, 3, 2, 3],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    # p1 has 2 and 2, so can't play 3
    success, _, _ = @game.play_card('p1', 3, 'p2')
    expect(success).to be == false
  end

  it 'forbids playing out of turn' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 2, 3, 2, 3],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    # player 2 can't play the 3 right now
    success, _, _ = @game.play_card('p2', 3, 'p1')
    expect(success).to be == false
  end

  it 'calculates the winner after the last card is played' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 2, 3, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    success, _, _ = @game.play_card('p1', 2, 'p2')
    expect(success).to be == true

    expect(@game.round_winner(1)).to be == 'p2'
    expect(@game.game_winner).to be == 'p2'
  end

  # ===== Tests with 1 =====

  context 'when playing a 1' do
    before :each do
      @game.start_game(
        %w(p1 p2),
        rigged_deck: [1, 1, 1, 1, 1, 3, 2],
        rigged_order: ['p1', 'p2']
      )
      @game.draw
      expect(@game.deck_size).to be == 0

      expect(@game.hand('p1')).to include(Card.new(1))
      expect(@game.hand('p2')).to be == [Card.new(3)]
    end

    it 'kills on a correct guess' do
      success, _, _ = @game.play_card('p1', 1, 'p2 3')
      expect(success).to be == true

      expect(@game.alive?('p2')).to be == false
    end

    it 'does not kill on an incorrect guess' do
      success, _, _ = @game.play_card('p1', 1, 'p2 2')
      expect(success).to be == true

      expect(@game.alive?('p2')).to be == true
    end

    it 'forbids guessing 9' do
      success, _, _ = @game.play_card('p1', 1, 'p2 9')
      expect(success).to be == false
    end

    it 'forbids guessing 1' do
      success, _, _ = @game.play_card('p1', 1, 'p2 1')
      expect(success).to be == false
    end

    it 'forbids guessing 0' do
      success, _, _ = @game.play_card('p1', 1, 'p2 0')
      expect(success).to be == false
    end

    it 'forbids guessing nothing' do
      success, _, _ = @game.play_card('p1', 1, 'p2')
      expect(success).to be == false
    end

    it 'forbids self-targeting' do
      success, _, _ = @game.play_card('p1', 1, 'p1 2')
      expect(success).to be == false
    end
  end

  it 'does not kill when playing 1 on protected player' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 4, 1, 3, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 4, '')
    expect(success).to be == true

    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to be == [Card.new(3)]

    success, _, _ = @game.play_card('p2', 1, 'p1 3')
    expect(success).to be == true

    expect(@game.alive?('p2')).to be == true
  end

  # ===== Tests with 2 =====

  it 'forbids self-targeting with a 2' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 2, 3, 1],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to include(Card.new(2))

    success, _, _ = @game.play_card('p1', 2, 'p1')
    expect(success).to be == false
  end

  # This is a weird test, since it kind of tests interface
  it 'reveals no information when playing a 2 on protected player' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 4, 2, 1, 3],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 4, '')
    expect(success).to be == true

    @game.draw
    expect(@game.deck_size).to be == 0

    success, _, privinfo = @game.play_card('p2', 2, 'p1')
    expect(success).to be == true
    expect(privinfo).to be_empty
  end

  # ===== Tests with 3 =====

  it 'kills the player who played a 3 if the player loses' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 3, 4, 2, 5],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    expect(@game.hand('p1')).to be == [Card.new(3), Card.new(2)]
    expect(@game.hand('p2')).to be == [Card.new(4)]

    success, _, _ = @game.play_card('p1', 3, 'p2')
    expect(success).to be == true

    expect(@game.alive?('p1')).to be == false
    expect(@game.alive?('p2')).to be == true
  end

  it 'kills the opponent of the player who played a 3 if the player wins' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 3, 2, 4, 5],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    expect(@game.hand('p1')).to be == [Card.new(3), Card.new(4)]
    expect(@game.hand('p2')).to be == [Card.new(2)]

    success, _, _ = @game.play_card('p1', 3, 'p2')
    expect(success).to be == true

    expect(@game.alive?('p1')).to be == true
    expect(@game.alive?('p2')).to be == false
  end

  it 'kills neither player when a 3 duel ties' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 3, 2, 2, 3],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    expect(@game.hand('p1')).to be == [Card.new(3), Card.new(2)]
    expect(@game.hand('p2')).to be == [Card.new(2)]

    success, _, _ = @game.play_card('p1', 3, 'p2')
    expect(success).to be == true

    expect(@game.alive?('p1')).to be == true
    expect(@game.alive?('p2')).to be == true
  end

  it 'does not battle when playing 3 on protected player' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 4, 3, 1, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 4, '')
    expect(success).to be == true

    @game.draw
    expect(@game.deck_size).to be == 0

    success, _, _ = @game.play_card('p2', 3, 'p1')
    expect(success).to be == true

    expect(@game.alive?('p1')).to be == true
    expect(@game.alive?('p2')).to be == true
  end

  it 'forbids self-targeting with a 3' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 3, 2, 1],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to include(Card.new(3))

    success, _, _ = @game.play_card('p1', 3, 'p1')
    expect(success).to be == false
  end

  # ===== Tests with 4 =====

  it 'allows playing 4 without arguments' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 4, 2, 1],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    success, _, _ = @game.play_card('p1', 4, '')
    expect(success).to be == true
  end

  # ===== Tests with 5 =====

  context 'when playing 5 with a many-card deck' do
    before :each do
      @game.start_game(
        %w(p1 p2),
        rigged_deck: [1, 1, 1, 1, 5, 1, 2, 3, 4],
        rigged_order: ['p1', 'p2']
      )
      @game.draw
      expect(@game.deck_size).to be == 2

      expect(@game.hand('p1')).to be == [Card.new(5), Card.new(2)]
      expect(@game.hand('p2')).to be == [Card.new(1)]
    end

    it 'discards card when playing a 5 on opponent' do
      success, _, _ = @game.play_card('p1', 5, 'p2')
      expect(success).to be == true

      expect(@game.hand('p1')).to be == [Card.new(2)]
      expect(@game.hand('p2')).to be == [Card.new(3)]
    end

    it 'discards card when playing a 5 on self' do
      success, _, _ = @game.play_card('p1', 5, 'p1')
      expect(success).to be == true

      expect(@game.hand('p1')).to be == [Card.new(3)]
      expect(@game.hand('p2')).to be == [Card.new(1)]
    end
  end

  context 'when playing 5 with a one-card deck' do
    context 'when playing 5 on self' do
      before :each do
        @game.start_game(
          %w(p1 p2),
          rigged_deck: [1, 1, 1, 1, 5, 2, 1, 3],
          rigged_order: ['p1', 'p2']
        )
        @game.draw
        expect(@game.deck_size).to be == 1

        expect(@game.hand('p1')).to be == [Card.new(5), Card.new(1)]
        expect(@game.hand('p2')).to be == [Card.new(2)]

        success, _, _ = @game.play_card('p1', 5, 'p1')
        expect(success).to be == true
      end

      it 'discards the card' do
        expect(@game.hand('p1')).to be == [Card.new(3)]
        expect(@game.hand('p2')).to be == [Card.new(2)]
      end

      it 'calculates the winner using the new card' do
        expect(@game.round_winner(1)).to be == 'p1'
        expect(@game.game_winner).to be == 'p1'
      end
    end

    context 'when playing 5 on opponent' do
      before :each do
        @game.start_game(
          %w(p1 p2),
          rigged_deck: [1, 1, 1, 1, 5, 1, 2, 3],
          rigged_order: ['p1', 'p2']
        )
        @game.draw
        expect(@game.deck_size).to be == 1

        expect(@game.hand('p1')).to be == [Card.new(5), Card.new(2)]
        expect(@game.hand('p2')).to be == [Card.new(1)]

        success, _, _ = @game.play_card('p1', 5, 'p2')
        expect(success).to be == true
      end

      it 'discards the card' do
        expect(@game.hand('p1')).to be == [Card.new(2)]
        expect(@game.hand('p2')).to be == [Card.new(3)]
      end

      it 'calculates the winner using the new card' do
        expect(@game.round_winner(1)).to be == 'p2'
        expect(@game.game_winner).to be == 'p2'
      end
    end
  end

  context 'when playing 5 with an empty deck' do
    context 'when playing 5 on self' do
      before :each do
        @game.start_game(
          %w(p1 p2),
          rigged_deck: [8, 1, 1, 1, 5, 2, 1],
          rigged_order: ['p1', 'p2']
        )
        @game.draw
        expect(@game.deck_size).to be == 0

        expect(@game.hand('p1')).to be == [Card.new(5), Card.new(1)]
        expect(@game.hand('p2')).to be == [Card.new(2)]

        success, _, _ = @game.play_card('p1', 5, 'p1')
        expect(success).to be == true
      end

      it 'allows the target of 5 to draw the facedown card' do
        expect(@game.hand('p1')).to be == [Card.new(8)]
        expect(@game.hand('p2')).to be == [Card.new(2)]
      end

      it 'calculates the winner using the new card' do
        expect(@game.round_winner(1)).to be == 'p1'
        expect(@game.game_winner).to be == 'p1'
      end
    end

    context 'when playing 5 on opponent' do
      before :each do
        @game.start_game(
          %w(p1 p2),
          rigged_deck: [8, 1, 1, 1, 5, 1, 2],
          rigged_order: ['p1', 'p2']
        )
        @game.draw
        expect(@game.deck_size).to be == 0

        expect(@game.hand('p1')).to be == [Card.new(5), Card.new(2)]
        expect(@game.hand('p2')).to be == [Card.new(1)]

        success, _, _ = @game.play_card('p1', 5, 'p2')
        expect(success).to be == true
      end

      it 'allows the target of 5 to draw the facedown card' do
        expect(@game.hand('p1')).to be == [Card.new(2)]
        expect(@game.hand('p2')).to be == [Card.new(8)]
      end

      it 'calculates the winner using the new card' do
        expect(@game.round_winner(1)).to be == 'p2'
        expect(@game.game_winner).to be == 'p2'
      end
    end
  end

  it 'does not discard when playing a 5 on protected player' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 4, 5, 1, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 4, '')
    expect(success).to be == true

    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to be == [Card.new(1)]
    expect(@game.hand('p2')).to be == [Card.new(5), Card.new(2)]

    success, _, _ = @game.play_card('p2', 5, 'p1')
    expect(success).to be == true

    expect(@game.hand('p1')).to be == [Card.new(1)]
    expect(@game.hand('p2')).to be == [Card.new(2)]
  end

  it 'kills a player who self-discards an 8 because of a 5' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 5, 1, 8, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 5, 'p1')
    expect(success).to be == true

    expect(@game.alive?('p1')).to be == false
  end

  it 'kills an opponent who discards an 8 because of a 5' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 5, 8, 1, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 5, 'p2')
    expect(success).to be == true

    expect(@game.alive?('p2')).to be == false
  end

  # ===== Tests with 6 =====

  it 'trades hands when playing a 6' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 6, 2, 1],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to be == [Card.new(6), Card.new(1)]
    expect(@game.hand('p2')).to be == [Card.new(2)]

    success, _, _ = @game.play_card('p1', 6, 'p2')
    expect(success).to be == true

    expect(@game.hand('p1')).to be == [Card.new(2)]
    expect(@game.hand('p2')).to be == [Card.new(1)]
  end

  it 'forbids self-targeting with a 6' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 6, 2, 1],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to be == [Card.new(6), Card.new(1)]
    expect(@game.hand('p2')).to be == [Card.new(2)]

    success, _, _ = @game.play_card('p1', 6, 'p1')
    expect(success).to be == false
  end

  it 'does not trade hands when playing 6 on protected player' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 4, 6, 1, 2],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 1

    success, _, _ = @game.play_card('p1', 4, '')
    expect(success).to be == true

    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to be == [Card.new(1)]
    expect(@game.hand('p2')).to be == [Card.new(6), Card.new(2)]

    success, _, _ = @game.play_card('p2', 6, 'p1')
    expect(success).to be == true

    expect(@game.hand('p1')).to be == [Card.new(1)]
    expect(@game.hand('p2')).to be == [Card.new(2)]
  end

  # ===== Tests with 7 =====

  it 'allows playing 7 without arguments' do
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 7, 2, 1],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    success, _, _ = @game.play_card('p1', 7, '')
    expect(success).to be == true
  end

  context 'when a player holds 12+ with 7 in hand' do
    before :each do
      @game.minister_death = true
      @game.start_game(
        %w(p1 p2),
        rigged_deck: [1, 1, 1, 1, 7, 1, 5, 2],
        rigged_order: ['p1', 'p2']
      )
      @game.draw
      expect(@game.deck_size).to be == 1
    end

    it 'kills the offending player' do
      expect(@game.alive?('p1')).to be == false
    end

    it 'calculates the winner' do
      expect(@game.round_winner(1)).to be == 'p2'
      expect(@game.game_winner).to be == 'p2'
    end
  end

  it 'forces players who hold 12+ with 7 in hand to play 7' do
    @game.minister_death = false
    @game.start_game(
      %w(p1 p2),
      rigged_deck: [1, 1, 1, 1, 7, 1, 5],
      rigged_order: ['p1', 'p2']
    )
    @game.draw
    expect(@game.deck_size).to be == 0

    expect(@game.hand('p1')).to be == [Card.new(7), Card.new(5)]

    # minister death is false, so player 1 is still alive
    expect(@game.alive?('p1')).to be == true

    # can't play the 5
    success, _, _ = @game.play_card('p1', 5, 'p2')
    expect(success).to be == false

    # can play the 7
    success, _, _ = @game.play_card('p1', 7, '')
    expect(success).to be == true
  end

  # ===== Tests with 8 =====

  context 'when a player plays an 8' do
    before :each do
      @game.start_game(
        %w(p1 p2),
        rigged_deck: [1, 1, 1, 1, 8, 1, 2, 2],
        rigged_order: ['p1', 'p2']
      )
      @game.draw
      expect(@game.deck_size).to be == 1

      success, _, _ = @game.play_card('p1', 8, '')
      expect(success).to be == true
    end

    it 'kills the player' do
      expect(@game.alive?('p1')).to be == false
    end

    it 'calculates the winner' do
      expect(@game.round_winner(1)).to be == 'p2'
      expect(@game.game_winner).to be == 'p2'
    end
  end
end
