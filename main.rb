require './lib/mastermind'
include Mastermind

p = ComputerPlayer.new
board = Board.new
res = board.add_guess(p.guess)
p.analyze_results(res)
