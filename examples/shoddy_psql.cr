require "../src/pg"

DB = PG.connect(ARGV[0])

loop do
  print "# "
  query = gets.not_nil!.chomp
  puts
  DB.exec(query) do |row|
    p row
  end
  puts
end
