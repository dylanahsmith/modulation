require 'modulation'

Factorial = import('factorial')

puts "Using #call:"
(1..5).each {|i| puts "factorial(#{i}) = #{Factorial.(i)}"}

puts "Using #to_proc:"
puts "Results: #{(1..5).map(&Factorial)}"

