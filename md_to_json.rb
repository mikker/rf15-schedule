require 'date'
require 'json'

puts 'Generating schedule.json'

path = "./schedule.md"
dest = './schedule.json'

file = open(path).read
days = file.split(/^# [A-Z]+$/m)
days.shift # header
days.map!(&:strip)

dates = (28..30).to_a.map { |d| Date.new(2015, 6, d) } +
  (1..4).to_a.map { |d| Date.new(2015, 7, d) }

class Concert
  def initialize artist, stage, time
    @artist, @stage, @time = artist, stage, time
  end

  attr_accessor :artist, :stage, :time

  def to_json opts = {}
    { artist: artist, stage: stage, time: time }.to_json
  end
end

concerts = dates.zip(days).map do |date, table|
  lines = table.split("\n").map do |line|
    line.split(/\s?\|\s?/).map(&:strip).compact
  end
  stages = lines.shift
  stages.shift(2) # first bar and TIME
  lines.shift # divider
  lines.inject([]) do |concerts, columns|
    columns.shift # first bar
    hour = columns.shift
    columns.each_with_index do |column, i|
      next if column == ""

      match = column.match(/\+(\d{2})\s(.*)/)
      minute = match[1].to_i
      artist = match[2]
      stage = stages[i]
      time = Time.new(date.year, date.month, date.day, hour, minute)
      concerts.push Concert.new(artist, stage, time)
    end

    concerts
  end
end.flatten.sort { |a, b| a.artist <=> b.artist }

File.open(dest, 'w') do |f|
  f.write concerts.to_json
end

