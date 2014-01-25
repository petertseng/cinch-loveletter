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

module LoveLetter; class Card
  USAGES = [
    'Card zero',
    '!play 1 player card',
    '!play 2 player',
    '!play 3 player',
    '!play 4',
    '!play 5 player',
    '!play 6 player',
    '!play 7',
    '!play 8',
  ].freeze

  SHORTHELP = [
    'Card zero',
    'Guess opponent\'s card',
    'Look at opponent\'s card',
    'Duel!',
    'Protect self',
    'Force opponent or self to discard',
    'Trade hand with opponent',
    'No effect, but avoid 12+',
    'Lose!',
  ].freeze

  JNAMES = [
    'Card zero',
    'Soldier',
    'Clown',
    'Knight',
    'Priestess',
    'Wizard',
    'General',
    'Minister',
    'Princess',
  ].freeze

  TNAMES = [
    'Card zero',
    'Guard',
    'Priest',
    'Baron',
    'Handmaiden',
    'Prince',
    'King',
    'Countess',
    'Princess',
  ].freeze

  attr_reader :id

  class << self
    attr_accessor :names
  end

  @@names = TNAMES

  def initialize(id)
    @id = id
  end

  def self.name(id)
    "#{@@names[id]} (#{id})"
  end

  def usage
    USAGES[@id]
  end

  def jname
    JNAMES[@id]
  end

  def tname
    TNAMES[@id]
  end

  def to_s
    Card.name(@id)
  end

  def short_help
    "#{@@names[@id]} (#{@id}, #{SHORTHELP[@id]})"
  end

  def ==(that)
    @id == that.id
  end
end; end
