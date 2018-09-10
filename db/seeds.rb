# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

puts "@@@@@@@@@@ SEEDING STARTED @@@@@@@@@@"

puts "########## REAL USERS SEEDING STARTED ##########"

puts "---------- CREATING USER 1 ----------"

mario_rossi = User.new(first_name: "Mario", last_name: "Rossi", email: 'mail@mail.com', orcid:'0000-0002-1825-0097', password: '123456', password_confirmation: '123456')
mario_rossi.save

puts "---------- CREATION COMPLETED ----------"

puts "########## REAL USERS SEEDING COMPLETED ##########"

puts "########## FAKE USERS SEEDING STARTED ##########"

 5.times do |index|
 	puts "---------- CREATING FAKE USER #{index} ----------"

 	fake_user = User.new(first_name: "FirstName#{index}", last_name: "LastName#{index}", email: "Email#{index}@mail.com", password: '123456', password_confirmation: '123456')
 	fake_user.save

 	puts "---------- CREATION COMPLETED ----------"
 end

puts "########## FAKE USERS SEEDING COMPLETED #########"

puts "########## PUBLICATIONS SEEDING STARTED ##########"

p1 = Publication.new({pdf_url: "https://link.springer.com/content/pdf/10.1140%2Fepjc%2Fs10052-018-6047-y.pdf"})
p2 = Publication.new({pdf_url: "https://arxiv.org/pdf/1611.04642.pdf"})
p3 = Publication.new({pdf_url: "https://arxiv.org/pdf/1608.07878.pdf"})
p4 = Publication.new({pdf_url: "https://innovation-entrepreneurship.springeropen.com/track/pdf/10.1186/s13731-018-0086-3"})
p5 = Publication.new({pdf_url: "https://geochemicaltransactions.springeropen.com/track/pdf/10.1186/s12932-018-0056-5"})

auth_token = "bf9c15d6a6ad390c36915fe31649d1c66dfc836fc5a8739ea7c0823f0879a730$$RpkBx+0OSzzQWvis2/cLJ9eqDpkXibVcERKSG1ZLHOYvmuHJTcO4JJEQBC2h5bauj85OUU3CSTb7iZvrGx2KxMKm/b9c5KAo+KwfSfmQOj4uIclTAk12o3Wp2k/UVgSMU9NMyxFmb6S/5+YKkH+7gD+5k9fKeQ==--4vM+DLuTaxGyv5ce--pkUJwp+xPVgORbtUMGugxA=="

puts "---------- FETCHING FILE FOR PUBLICATION 1 ----------"
p1.save
p1.fetch auth_token
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 2 ----------"
p2.save
p2.fetch auth_token
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 3 ----------"
p3.save
p3.fetch auth_token
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 4 ----------"
p4.save
p4.fetch auth_token
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 5 ----------"
p5.save
p5.fetch auth_token
puts "---------- FETCHING COMPLETED ----------"

puts "########## PUBLICATIONS SEEDING COMPLETED ##########"

puts "########## FAKE RATINGS SEEDING STARTED ##########"

80.times do |index|
	puts "---------- CREATING FAKE RATING #{index} ----------"

 	random_publication_id = Publication.pluck(:id).shuffle[0]
 	random_user_id = User.pluck(:id).shuffle[0]
 	fake_rating = Rating.new
 	fake_rating.score = rand(0..100)
 	fake_rating.publication_id = random_publication_id
 	fake_rating.user_id = random_user_id
 	fake_rating.save

	sm_strategy = SMStrategy.new(fake_rating)
	readersourcing = Readersourcing.new(sm_strategy)
	readersourcing.compute_scores

 	puts "---------- CREATION COMPLETED ----------"
 end

puts "########## FAKE RATING SEEDING COMPLETED #########"

puts "@@@@@@@@@@ SEEDING COMPLETED @@@@@@@@@@"

