require 'set'

class Die
  attr_reader :value
  def initialize
    @value = :unrolled
  end

  def roll!
    @value = [1, 2, 3, 4, 5, 6].sample
  end

  def rolled?
    @value != :unrolled
  end

  def self.new_hand
    (1..5).to_a.map { new }
  end
end

class InvalidScorecardFieldError < StandardError
end

class DuplicateScoreAttemptError < StandardError
end

class ScoreBeforeRollError < StandardError
end

class IncompleteScorecardError < StandardError
end

class Game
  attr_reader :rolls_left

  def initialize
    @scorecard = {
      :ones   => nil,
      :twos   => nil,
      :threes => nil,
      :fours  => nil,
      :fives  => nil,
      :sixes  => nil,

      :three_of_a_kind => nil,
      :four_of_a_kind => nil,
      :full_house => nil,
      :small_straight => nil,
      :large_straight => nil,
      :yahtzee => nil,  # TODO: bonus
      :chance => nil,
    }

    @hand = Die.new_hand
    @rolls_left = 3
  end

  def hand
    @hand.map &:value
  end

  def roll!(indices)
    if @rolls_left == 0
      @hand = Die.new_hand
      @rolls_left = 3
    end

    indices.uniq.each do |i|
      @hand[i].roll!
    end

    @rolls_left -= 1
  end

  def scorecard_full?
    @scorecard.none? { |_, field_score| field_score.nil? }
  end

  def mark!(field)
    unless @scorecard.key? field
      raise InvalidScorecardFieldError
    end

    unless @scorecard[field].nil?
      raise DuplicateScoreAttemptError
    end

    unless @hand.all? &:rolled?
      raise ScoreBeforeRollError
    end

    case field
    when :ones
      @scorecard[:ones] = score_digit(1)
    when :twos
      @scorecard[:twos] = score_digit(2)
    when :threes
      @scorecard[:threes] = score_digit(3)
    when :fours
      @scorecard[:fours] = score_digit(4)
    when :fives
      @scorecard[:fives] = score_digit(5)
    when :sixes
      @scorecard[:sixes] = score_digit(6)
    when :three_of_a_kind
      triple = hand.group_by(&:itself).find { |_, dice| dice.count == 3 }
      @scorecard[:three_of_a_kind] = triple.nil? ? 0 : triple[0] * 3
    when :four_of_a_kind
      quadruple = hand.group_by(&:itself).find { |_, dice| dice.count == 4 }
      @scorecard[:four_of_a_kind] = quadruple.nil? ? 0 : quadruple[0] * 4
    when :full_house
      grouped = hand.group_by(&:itself)
      pair    = grouped.find { |_, dice| dice.count == 2 }
      triple  = grouped.find { |_, dice| dice.count == 3 }

      @scorecard[:full_house] = (pair && triple) ? 25 : 0
    when :small_straight
      hand_set = Set.new(hand)
      if Set[1,2,3,4].subset?(hand_set) || Set[2,3,4,5].subset?(hand_set) || Set[3,4,5,6].subset?(hand_set)
        @scorecard[:small_straight] = 30
      else
        @scorecard[:small_straight] = 0
      end
    when :large_straight
      hand_set = Set.new(hand)
      if Set[1,2,3,4,5].subset?(hand_set) || Set[2,3,4,5,6].subset?(hand_set)
        @scorecard[:large_straight] = 40
      else
        @scorecard[:large_straight] = 0
      end
    when :yahtzee
      @scorecard[:yahtzee] = hand.uniq.count == 1 ? 50 : 0
    when :chance
      @scorecard[:chance] = hand.sum
    else
      raise InvalidScorecardFieldError
    end

    @rolls_left = 3
  end

  def score
    unless scorecard_full?
      raise IncompleteScorecardError
    end

    upper = [:ones, :twos, :threes, :fours, :fives, :sixes].map { |field|
      @scorecard[field]
    }.sum
    bonus = (upper >= 63) ? 35 : 0

    @scorecard.map { |_, mark| mark }.sum + bonus
  end

  def scorecard
    upper = [:ones, :twos, :threes, :fours, :fives, :sixes].map { |field|
      @scorecard[field]
    }.sum
    bonus = (upper >= 63) ? 35 : 0

    lower = [:three_of_a_kind, :four_of_a_kind, :full_house, :small_straight, :large_straight, :yahtzee, :chance].map { |field|
      @scorecard[field]
    }.sum

    puts <<~CARD
      Ones    #{@scorecard[:ones]}
      Twos    #{@scorecard[:twos]}
      Threes  #{@scorecard[:threes]}
      Fours   #{@scorecard[:fours]}
      Fives   #{@scorecard[:fives]}
      Sixes   #{@scorecard[:sixes]}
      UPPER   #{upper}
      BONUS   #{bonus}
      TOTAL   #{upper + bonus}

      3-of-a-kind   #{@scorecard[:three_of_a_kind]}
      4-of-a-kind   #{@scorecard[:four_of_a_kind]}
      Full house    #{@scorecard[:full_house]}
      Sm Straight   #{@scorecard[:small_straight]}
      Lg Straight   #{@scorecard[:large_straight]}
      Yahtzee       #{@scorecard[:yahtzee]}
      Chance        #{@scorecard[:chance]}

      LOWER #{lower}
      UPPER #{upper + bonus}
      TOTAL #{upper + lower + bonus}
    CARD
  end

  private
  def score_digit(n)
    n * @hand.filter { |d| d.value == n }.count
  end
end

class Player
  def initialize
    @game = Game.new
  end

  def play!
    raise NotImplementedError
  end
end

class TopDownPlayer < Player
  def play!
    all_dice = [0, 1, 2, 3, 4]
    [
      :ones, :twos, :threes, :fours, :fives, :sixes,
      :three_of_a_kind, :four_of_a_kind, :full_house,
      :small_straight, :large_straight, :yahtzee, :chance,
    ].each do |field|
      @game.roll!(all_dice)
      @game.mark!(field)
    end
  end

  def score
    @game.score
  end

  def scorecard
    @game.scorecard
  end
end

attempts = 0
loop do
  attempts += 1
  p = TopDownPlayer.new
  p.play!

  if p.score > 200
    puts p.scorecard
    puts "Took #{attempts} attempts"
    break
  end
end