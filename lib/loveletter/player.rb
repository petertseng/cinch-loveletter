module LoveLetter; class Player
  attr_reader :name
  attr_reader :rounds_won
  attr_reader :alive
  attr_accessor :protected

  def initialize(name, channel_name)
    @name = name
    @channel_name = channel_name

    @rounds_won = 0
  end

  def start_round
    @hand = []
    @discards = []
    @alive = true
    @protected = false
  end

  alias :alive? :alive
  alias :protected? :protected
  alias :to_s :name

  def card
    raise "#{@name} has more than one card" unless @hand.size == 1
    @hand[0]
  end

  def has_card?(id)
    @hand.any? { |c| c.id == id }
  end

  def hand
    @hand.dup
  end

  def discards
    @discards.dup
  end

  def sum_hand
    @hand.map(&:id).inject(0, :+)
  end

  def ministered?
    has_card?(7) && sum_hand >= 12
  end

  def add_to_hand(card)
    @hand << card
  end

  def set_card(card, index)
    @hand[index] = card
  end

  def play_card_at(index)
    @discards << @hand[index]
    @hand.delete_at(index)
  end

  def discard_and_replace(card, index)
    @discards << @hand[index]
    set_card(card, index)
  end

  # Returns [my new card, their new card]
  def trade_hand_with(them, index)
    # Other player has 1 card
    their_card = them.card
    my_card = @hand[index]

    them.set_card(my_card, 0)
    @hand[index] = their_card

    [their_card, my_card]
  end

  def win_round
    raise "How did #{@name} win while dead?" unless @alive
    @rounds_won += 1
  end

  def die
    until @hand.empty?
      @discards << @hand.shift
    end
    @alive = false
  end
end; end
