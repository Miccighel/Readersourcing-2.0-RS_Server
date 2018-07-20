# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

puts "---------- SEEDING STARTED ----------"

p1 = Publication.new({pdf_url: "https://link.springer.com/content/pdf/10.1140%2Fepjc%2Fs10052-018-6047-y.pdf"})
p2 = Publication.new({pdf_url: "https://arxiv.org/pdf/1611.04642.pdf"})
p3 = Publication.new({pdf_url: "https://repo.scoap3.org/record/26902/files/main.pdf"})

puts "---------- FETCHING FILE FOR PUBLICATION 1 ----------"
p1.save
p1.fetch
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 2 ----------"
p2.save
p2.fetch
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 3 ----------"
p3.save
p3.fetch
puts "---------- SEEDING COMPLETED ----------"


