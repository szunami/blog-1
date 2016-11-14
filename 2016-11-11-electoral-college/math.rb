#!/usr/bin/env ruby

require 'tomlrb'

$file = Tomlrb.load_file File.join File.dirname(__FILE__), "data.toml"

$total_pop = $file["states"].to_a.map{|n|n[1]["pop"]}.reduce(:+)

def commafy number
	number.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/) { |s| "#{s}," }
end

# Generate a Markdown table listing the highest-populated metro areas
def table_cities
	yield "|Metro Region|Population (2015 est.)|Total Population|Total Share|"
	yield "|:-----------|---------------------:|---------------:|----------:|"
	data = $file["cities"]
	.to_a
	.sort_by do |elem|
		elem[1]
	end
	.reverse

	data.each_with_index do |elem, idx|
		# Sum the population encountered so far
		elem << data[0..idx]
		.map do |name, pop|
			pop
		end
		.reduce(:+)

		# Find the percent-of-total population encountered so far
		elem << elem[2].to_f / $total_pop.to_f
	end
	.each do |elem|
		yield [
			"",
			# City name
			elem[0].gsub("_", " "),
			# City population
			commafy(elem[1]),
			# Sum of population encountered so far
			commafy(elem[2]),
			# Sum of population percent encountered so far
			"%.2f%%" % (elem[3] * 100.0),
			"",
		].join "|"
	end

	nil
end

# Generates a Markdown table listing the fewest states needed to win
def table_minority_win
	yield "|State|Population|Majority|Total Voters|% of pop.|Electors|Total Electors|"
	yield "|:----|---------:|-------:|-----------:|--------:|-------:|-------------:|"
	data = $file["states"]
	.to_a
	.sort_by do |elem|
		elem[1]["pop"]
	end
	.reverse

	data.each_with_index do |elem, idx|
		# Find the smallest majority (half plus one)
		elem << elem[1]["pop"] / 2 + 1

		# Sum the smallest majorities yet seen
		elem << data[0..idx].map do |elem|
			elem[2]
		end
		.reduce(:+)

		# Find the percent-of-total of all smallest majorities yet seen
		elem << elem[3].to_f / $total_pop.to_f

		# Find the total electors encountered so far
		elem << data[0..idx].map do |elem|
			elem[1]["electors"]
		end
		.reduce(:+)
	end
	.slice(0...11)
	.each do |elem|
		yield [
			"",
			# State name
			elem[0].gsub("_", " "),
			# State population
			commafy(elem[1]["pop"]),
			# State majority
			commafy(elem[2]),
			# Sum of all majorities yet seen
			commafy(elem[3]),
			# Sum of all percents yet seen
			"%.2f%%" % (elem[4] * 100.0),
			# State electors
			elem[1]["electors"],
			# Sum of all electors yet seen
			elem[5],
			"",
		].join "|"
	end

	nil
end

def minority_win
	pops = $file["states"].map { |k, v| v["pop"] / 2 + 1 }.sort.reverse

	states = pops[0...11].reduce(:+)
	votes = pops[10..50].reduce(:+)

	[
		[commafy(states), "%.2f%%" % (states.to_f * 100.0 / $total_pop.to_f)],
		[commafy(votes), "%.2f%%" % (votes.to_f * 100.0 / $total_pop.to_f)],
	]
end

def majority_loss
	pops = $file["states"].map { |k, v| v["pop"] }.sort.reverse
	total =  pops[0...10].reduce(:+) + pops[12]
	total += pops[10...12].map { |n| n / 2 - 1 }.reduce(:+)
	total += pops[13..50].map { |n| n / 2 - 1 }.reduce(:+)

	[commafy(total), "%.2f%%" % (total.to_f * 100.0 / $total_pop.to_f)]
end
