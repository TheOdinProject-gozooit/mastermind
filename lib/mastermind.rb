module Mastermind
  COLORS = {
    G: 'GREEN',
    B: 'BLUE',
    R: 'RED',
    Y: 'YELLOW',
    P: 'PURPLE',
    C: 'CYAN'
  }.freeze

  class Code
    attr_reader :colors

    def initialize(input = nil)
      @colors = create_code_from_string(input) || self.class.generate_random_with_uniq_colors
    end

    def self.generate_random
      color_list = COLORS.keys.map(&:to_s)
      Array.new(4, '').map { color_list[rand(6)] }
    end

    def self.generate_random_with_uniq_colors
      color_list = COLORS.keys.map(&:to_s)
      color_list.shuffle.pop(4)
    end

    private

    # remove any whitespace or comma, then transform it to uppercase
    def format_input_string(str)
      str.gsub(/\s+/, '').gsub(/,/, '').upcase
    end

    def create_code_from_string(str)
      return nil if str.nil?

      unless input_string_valid?(str)
        raise StandardError, "'#{str}' is not valid, you have to chose from (#{COLORS.keys.map(&:to_s).join(', ')})"
      end

      format_input_string(str).split('')
    end

    def input_string_valid?(str)
      str = format_input_string(str)
      return false unless str.length == 4

      str.each_char.all? { |char| COLORS.keys.map(&:to_s).include?(char) }
    end
  end

  class Board
    def initialize(secret_code = nil)
      @secret_code = secret_code || Code.new.colors
      @grid = []
      @res = []
      puts "secret code is #{@secret_code}"
    end

    def display
      @grid.each_with_index do |line, index|
        puts line.join(' - ')
        print_result_to_symbols(@res[index])
        puts
      end
    end

    def add_guess(guessed_code)
      @grid << guessed_code
      @res << analyse_guessed_code(guessed_code)
      @res.last
    end

    def full?
      @grid.length == 12
    end

    def win?
      @res.last.all? { |res| res == true }
    end

    def turn_elapsed
      @grid.length
    end

    def analyse_guessed_code(guessed_code)
      guessed_code, secret_code = remove_matches_from_codes(guessed_code.dup, @secret_code.dup)
      find_misplaced_colors(guessed_code, secret_code)
    end

    private

    def print_result_to_symbols(result)
      result.each_with_index do |r, index|
        print '✓' if r == true
        print '𐄂' if r == false
        print '?' if r == '?'
        print index == 3 ? "\n" : ' - '
      end
    end

    def guess_match_secret?(guessed_code)
      result = []
      4.times { |i| result << (guessed_code[i] == @secret_code[i]) }
      result
    end

    def remove_matches_from_codes(guessed_code, secret_code)
      matches = guess_match_secret?(guessed_code)
      matches.each_with_index do |match, index|
        if match
          guessed_code[index] = match
          secret_code[index] = match
        end
      end
      [guessed_code, secret_code]
    end

    def find_misplaced_colors(guessed_code, secret_code)
      guessed_code.map do |color|
        next true if color == true

        if secret_code.include?(color)
          secret_code.delete_at(secret_code.index(color))
          '?'
        else
          false
        end
      end
    end
  end

  class Game
    def play
      print_presentation
      @board = Board.new
      loop do
        break lose if @board.full?

        play_turn
        break win if @board.win?
      end
    end

    private

    def print_presentation
      puts 'Welcome to Mastermind!'
      puts
      puts 'You have to guess the secret code compose of 4 of the following colors :'
      puts COLORS.values.join(', ')
      puts
      puts 'The input has to be formated such as "CCCC", "C C C C" or "C, C, C, C" where C stands for [C]OLOR'
      puts
    end

    def win
      puts "Congratulation you found the secret code in #{@board.turn_elapsed} turns."
    end

    def lose
      puts "Unfortunately you didn't found the secret code at time (12 turns elapsed)."
    end

    def play_turn
      puts 'Please enter your guess :'
      guess = gets.chomp
      loop do
        code = Code.new(guess)
      rescue StandardError => e
        puts e.message
        puts 'Please enter a correct guess (ex: R B Y C) :'
        guess = gets.chomp
      else
        @board.add_guess(code.colors)
        puts
        @board.display
        puts
        break
      end
    end
  end

  class ComputerPlayer
    attr_reader :guess

    def initialize
      @guess = Code.generate_random_with_uniq_colors
      @previous_guess = nil
      @possibilities = Array.new(4) { COLORS.keys.map(&:to_s) }
    end

    def analyze_results(results)
      @previous_guess = @guess.dup
      results.each_with_index do |result, index|
        if result == true
          good_guess(index)
        elsif result == false
          bad_guess(index)
        else
          misplaced_guess(index)
        end
      end
    end

    private

    def good_guess(index)
      color = @previous_guess[index]
      @possibilities[index] = color
      @possibilities.each do |possibility|
        next if possibility.is_a?(String)

        possibility.delete(color)
      end
    end

    def bad_guess(index)
      color = @previous_guess[index]
      @possibilities.each do |possibility|
        next if possibility.is_a?(String)

        possibility.delete(color)
      end
    end

    def misplaced_guess(index)
      color = @previous_guess[index]
      @possibilities[index].delete(color)
    end
  end
end
