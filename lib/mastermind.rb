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

    def create_code_from_string(input)
      return nil if input.nil?

      str = format_input_string(input)

      unless input_string_valid?(str)
        raise StandardError, "'#{input}' is not valid, you have to chose from (#{COLORS.keys.map(&:to_s).join(', ')})"
      end

      raise StandardError, "'#{input}' is not valid, each color has to be unique." unless uniq_colors?(str)

      str.split('')
    end

    def input_string_valid?(str)
      return false unless str.length == 4

      str.each_char.all? { |char| COLORS.keys.map(&:to_s).include?(char) }
    end

    def uniq_colors?(str)
      seen_characters = {}

      str.each_char do |char|
        return false if seen_characters[char]

        seen_characters[char] = true
      end

      true
    end
  end

  class Board
    def initialize(secret_code = nil)
      @secret_code = secret_code || Code.new.colors
      @grid = []
      @res = []
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

    private

    def analyse_guessed_code(guessed_code)
      guessed_code, secret_code = remove_matches_from_codes(guessed_code.dup, @secret_code.dup)
      find_misplaced_colors(guessed_code, secret_code)
    end

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
    def initialize(guesser)
      @guesser = guesser
    end

    def play
      if @guesser == 'human'
        human_play
      elsif @guesser == 'computer'
        computer_play(input_user_code.colors)
      end
    end

    private

    def human_play
      print_presentation
      @board = Board.new
      loop do
        break lose if @board.full?

        human_play_turn
        break win if @board.win?
      end
    end

    def human_play_turn
      code = input_user_code
      @board.add_guess(code.colors)
      puts
      @board.display
      puts
    end

    def input_user_code
      puts 'Please enter your code :'
      guess = gets.chomp
      loop do
        code = Code.new(guess)
      rescue StandardError => e
        puts "#{e.message}\nPlease enter a valid code (ex: R B Y C) :"
        guess = gets.chomp
      else
        break code
      end
    end

    def computer_play(secret_code)
      rob = ComputerPlayer.new
      @board = Board.new(secret_code)
      loop do
        break lose if @board.full?

        computer_play_turn(rob)
        break win if @board.win?
      end
    end

    def computer_play_turn(rob)
      result = @board.add_guess(rob.guess)
      puts
      @board.display
      puts
      rob.analyze_results(result)
      rob.generate_guess
    end

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
  end

  class ComputerPlayer
    attr_reader :guess

    def initialize
      @guess = Code.generate_random_with_uniq_colors
      @previous_guess = nil
      @possibilities = Array.new(4) { COLORS.keys.map(&:to_s) }
    end

    # update @possibilities from result of the previous guess
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

    def generate_guess
      initialize_guess
      # the following create a deep copy (.dup creates a shallow copy)
      possibilities = Marshal.load(Marshal.dump(@possibilities))
      while @guess.any?(&:nil?)
        index = shortest_array_index(possibilities)
        @guess[index] = pick_color_from_possibilities(possibilities, index)
      end
      Code.new(@guess.join(' ')).colors
    end

    private

    # reset @guess then set already found colors
    def initialize_guess
      @guess = Array.new(4)
      @possibilities.each_with_index do |possibility, index|
        @guess[index] = possibility if possibility.is_a?(String)
      end
    end

    # return index of the shortest array in a given array
    def shortest_array_index(arr)
      shortest_array_index = nil
      shortest_array_length = Float::INFINITY

      arr.each_with_index do |elem, index|
        if elem.is_a?(Array) && elem.length < shortest_array_length
          shortest_array_index = index
          shortest_array_length = elem.length
        end
      end
      shortest_array_index
    end

    # count the element occurence in an array of arrays
    def count_element_occurence(arr)
      arr = arr.select { |elem| elem.is_a?(Array) && !elem.empty? }
      arr.flatten.group_by(&:itself).transform_values(&:count)
    end

    def least_occurent_color_in_pool(possibilities, pool)
      counts = count_element_occurence(possibilities)
      counts.select! { |i| pool.include?(i) }
      counts.min_by { |_, count| count }[0]
    end

    def pick_color_from_possibilities(possibilities, index)
      pool = possibilities[index]
      color = least_occurent_color_in_pool(possibilities, pool)
      possibilities.each { |possibility| possibility&.delete(color) }
      possibilities[index] = nil
      color
    end

    # remove color from each possibility and set current index possibility as known (string)
    def good_guess(index)
      color = @previous_guess[index]
      @possibilities[index] = color
      @possibilities.each do |possibility|
        next if possibility.is_a?(String)

        possibility.delete(color)
      end
    end

    # remove color from each possibility
    def bad_guess(index)
      color = @previous_guess[index]
      @possibilities.each do |possibility|
        next if possibility.is_a?(String)

        possibility.delete(color)
      end
    end

    # remove color from current index possibility
    def misplaced_guess(index)
      color = @previous_guess[index]
      @possibilities[index].delete(color)
    end
  end
end
