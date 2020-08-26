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

  def score_for(field)
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
      score_digit(1)
    when :twos
      score_digit(2)
    when :threes
      score_digit(3)
    when :fours
      score_digit(4)
    when :fives
      score_digit(5)
    when :sixes
      score_digit(6)
    when :three_of_a_kind
      triple = hand.group_by(&:itself).find { |_, dice| dice.count == 3 }
      triple.nil? ? 0 : triple[0] * 3
    when :four_of_a_kind
      quadruple = hand.group_by(&:itself).find { |_, dice| dice.count == 4 }
      quadruple.nil? ? 0 : quadruple[0] * 4
    when :full_house
      grouped = hand.group_by(&:itself)
      pair    = grouped.find { |_, dice| dice.count == 2 }
      triple  = grouped.find { |_, dice| dice.count == 3 }

      (pair && triple) ? 25 : 0
    when :small_straight
      hand_set = Set.new(hand)
      if Set[1,2,3,4].subset?(hand_set) || Set[2,3,4,5].subset?(hand_set) || Set[3,4,5,6].subset?(hand_set)
        30
      else
        0
      end
    when :large_straight
      hand_set = Set.new(hand)
      if Set[1,2,3,4,5].subset?(hand_set) || Set[2,3,4,5,6].subset?(hand_set)
        40
      else
        0
      end
    when :yahtzee
      hand.uniq.count == 1 ? 50 : 0
    when :chance
      hand.sum
    else
      raise InvalidScorecardFieldError
    end
  end

  def mark!(field)
    @scorecard[field] = score_for(field)

    @rolls_left = 3
  end

  def score
    unless scorecard_full?
      raise IncompleteScorecardError
    end

    @scorecard.map { |_, mark| mark }.sum + bonus
  end

  def scorecard
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

  def upper
    [:ones, :twos, :threes, :fours, :fives, :sixes].map { |field|
      @scorecard[field]
    }.sum
  end
  
  def bonus
    (upper >= 63) ? 35 : 0
  end
end

class Player
  ALL_DICE = [0, 1, 2, 3, 4]
  ALL_FIELDS = [
    :ones, :twos, :threes, :fours, :fives, :sixes,
    :three_of_a_kind, :four_of_a_kind, :full_house,
    :small_straight, :large_straight, :yahtzee, :chance,
  ]

  def initialize
    @game = Game.new
  end

  def play!
    raise NotImplementedError
  end

  def score
    @game.score
  end

  def scorecard
    @game.scorecard
  end
end

class TopDownPlayer < Player
  def play!
    ALL_FIELDS.each do |field|
      @game.roll!(ALL_DICE)
      @game.mark!(field)
    end
  end
end

class GreedyPlayer < Player
  def play!
    until @game.scorecard_full?
      @game.roll!(ALL_DICE)
      best_field = ALL_FIELDS.max_by { |field|
        begin
          @game.score_for(field)
        rescue
          -1
        end
      }

      @game.mark!(best_field)
    end
  end
end

attempts = 0
loop do
  attempts += 1
  p = GreedyPlayer.new
  p.play!

  if p.score > 200
    puts p.scorecard
    puts "Took #{attempts} attempts"
    break
  end
end