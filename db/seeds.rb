# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

puts "@@@@@@@@@@ SEEDING STARTED @@@@@@@@@@"

puts "########## USERS SEEDING STARTED ##########"

puts "---------- CREATING USER 1 ----------"

mario_rossi = User.new(first_name: "Mario", last_name: "Rossi", email: 'mail@mail.com', password: '123456', password_confirmation: '123456')
mario_rossi.save

puts "---------- CREATION COMPLETED ----------"

puts "########## USERS SEEDING COMPLETED ##########"

puts "########## PUBLICATIONS SEEDING STARTED ##########"

p1 = Publication.new({pdf_url: "https://link.springer.com/content/pdf/10.1140%2Fepjc%2Fs10052-018-6047-y.pdf"})
p2 = Publication.new({pdf_url: "https://arxiv.org/pdf/1611.04642.pdf"})
p3 = Publication.new({pdf_url: "https://arxiv.org/pdf/1608.07878.pdf"})
p4 = Publication.new({pdf_url: "https://innovation-entrepreneurship.springeropen.com/track/pdf/10.1186/s13731-018-0086-3"})
p5 = Publication.new({pdf_url: "https://geochemicaltransactions.springeropen.com/track/pdf/10.1186/s12932-018-0056-5"})
p6 = Publication.new({pdf_url: "https://crimesciencejournal.springeropen.com/track/pdf/10.1186/s40163-018-0081-9"})

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
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 4 ----------"
p4.save
p4.fetch
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 5 ----------"
p5.save
p5.fetch
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 6 ----------"
p6.save
p6.fetch
puts "---------- FETCHING COMPLETED ----------"

puts "########## PUBLICATIONS SEEDING COMPLETED ##########"

puts "@@@@@@@@@@ SEEDING COMPLETED @@@@@@@@@@"



