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

mario_rossi = User.new(first_name: "Mario", last_name: "Rossi", email: 'rossi@mail.com', email_confirmed: true, subscribe: true, password: '123456', password_confirmation: '123456')
mario_rossi.save

puts "---------- CREATION COMPLETED ----------"

puts "---------- CREATING USER 2 ----------"

luca_bianchi = User.new(first_name: "Luca", last_name: "Bianchi", email: 'bianchi@mail.com', email_confirmed: true, subscribe: true, password: '123456', password_confirmation: '123456')
luca_bianchi.save

puts "---------- CREATION COMPLETED ----------"

puts "---------- CREATING USER 3 ----------"

giovanni_verdi = User.new(first_name: "Giovanni", last_name: "Verdi", email: 'verdi@mail.com', email_confirmed: true, subscribe: true, password: '123456', password_confirmation: '123456')
giovanni_verdi.save

puts "---------- CREATION COMPLETED ----------"

puts "---------- CREATING USER 4 ----------"

elisa_gialli = User.new(first_name: "Elisa", last_name: "Gialli", email: 'gialli@mail.com', email_confirmed: true, subscribe: true, password: '123456', password_confirmation: '123456')
elisa_gialli.save

puts "---------- CREATION COMPLETED ----------"

puts "########## REAL USERS SEEDING COMPLETED ##########"

puts "########## FAKE USERS SEEDING STARTED ##########"

5.times do |index|
 	puts "---------- CREATING FAKE USER #{index} ----------"

 	fake_user = User.new(first_name: "FirstName_#{index}", last_name: "LastName_#{index}", email: "email_#{index}@mail.com", subscribe: false, password: '123456', password_confirmation: '123456')
 	fake_user.save

 	puts "---------- CREATION COMPLETED ----------"
 end

puts "########## FAKE USERS SEEDING COMPLETED #########"


puts "########## PUBLICATIONS SEEDING STARTED ##########"

p1 = Publication.new({pdf_url: "https://arxiv.org/pdf/1608.07878.pdf"})
p2 = Publication.new({pdf_url: "https://zenodo.org/record/3245218/files/Documentation-v1.0.6-alpha.pdf?download=1"})
p3 = Publication.new({pdf_url: "https://zenodo.org/record/1446468/files/paper.pdf?download=1"})
p4 = Publication.new({pdf_url: "https://arxiv.org/pdf/1807.04317.pdf"})
p5 = Publication.new({pdf_url: "http://ceur-ws.org/Vol-1911/8.pdf"})

auth_token = "3a7b11756ea2b8a983f918a63346bdfd695adbc39028218e0a0d49909af60595!!!!!l8B3IrSFRuXSc1ZvyTgNJsZ67+lXfBMVrQYYiefxWCNQ2TvQTT6zEScC/phjm/GnEomSwCp+wQCAilj902c3NBPFqaMTASjyJUkPFjHXohZWIe7AP1+L2dOuY766piLfETP1a1tKwCRt1VAprRO83S1rd53ncm0Pp5yZOvM+Gqm+YRKVKyz0mfwvXKu/14X7oMBj4yPZ2m6mmBRA65V4GH4PO3RyiA==--AL1d9u9ZBmZvN8ru--3QobO/8AB0Gf3DJ1VS7U9w=="
data = Hash.new
data[:authToken] = auth_token
data[:host] = "http://rs-server.herokuapp.com"
data[:user] = mario_rossi

puts "---------- FETCHING FILE FOR PUBLICATION 1 ----------"
p1.save
p1.fetch data
p1.remove_files(data[:user])
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 2 ----------"
p2.save
p2.fetch data
p2.remove_files(data[:user])
puts "---------- FETCHING COMPLETED ----------"

puts "---------- FETCHING FILE FOR PUBLICATION 3 ----------"
p3.save
p3.fetch data
p3.remove_files(data[:user])
puts "---------- FETCHING COMPLETED ----------"

data[:user] = luca_bianchi

puts "---------- FETCHING FILE FOR PUBLICATION 4 ----------"
p4.save
p4.fetch data
p4.remove_files(data[:user])
puts "---------- FETCHING COMPLETED ----------"

data[:user] = mario_rossi

puts "---------- FETCHING FILE FOR PUBLICATION 5 ----------"
p5.save
p5.fetch data
p5.remove_files(data[:user])
puts "---------- FETCHING COMPLETED ----------"

puts "########## PUBLICATIONS SEEDING COMPLETED ##########"

puts "########## RANDOM SIMULATION STARTED ##########"

40.times do |index|
	puts "---------- CREATING FAKE RATING #{index} ----------"

	random_publication_id = Publication.pluck(:id).shuffle[0]
	random_user_id = User.pluck(:id).shuffle[0]
	fake_rating = Rating.new
    score = rand(30..100)
	fake_rating.score = score
	fake_rating.original_score = score
	fake_rating.publication_id = random_publication_id
	fake_rating.user_id = random_user_id
	fake_rating.save

	sm_strategy = RsmStrategy.new(fake_rating)
	readersourcing = Readersourcing.new(sm_strategy)
	readersourcing.compute_scores

	tr_strategy = TrmStrategy.new(fake_rating)
	readersourcing = Readersourcing.new(tr_strategy)
	readersourcing.compute_scores
	puts "---------- CREATION COMPLETED ----------"
 end

# puts "########## RANDOM SIMULATION COMPLETED ##########"

# puts "########## GROUND_TRUTH_1 SIMULATION STARTED #########"
#
# publication_id_1 = 1
# publication_id_2 = 2
# user_id_1 = 1
# user_id_2 = 2
# user_id_3 = 3
# user_id_4 = 4
#
# rating_1 = Rating.new
# rating_1.score = 80
# rating_1.original_score = 80
# rating_1.user_id = user_id_1
# rating_1.publication_id = publication_id_1
# rating_1.save
#
# sm_strategy = RsmStrategy.new(rating_1)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_1)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_2 = Rating.new
# rating_2.score = 20
# rating_2.original_score = 20
# rating_2.user_id = user_id_2
# rating_2.publication_id = publication_id_1
# rating_2.save
#
# sm_strategy = RsmStrategy.new(rating_2)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_2)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_3 = Rating.new
# rating_3.score = 20
# rating_3.original_score = 20
# rating_3.user_id = user_id_3
# rating_3.publication_id = publication_id_1
# rating_3.save
#
# sm_strategy = RsmStrategy.new(rating_3)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_3)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_4 = Rating.new
# rating_4.score = 50
# rating_4.original_score = 50
# rating_4.user_id = user_id_3
# rating_4.publication_id = publication_id_2
# rating_4.save
#
# sm_strategy = RsmStrategy.new(rating_4)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_4)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_5 = Rating.new
# rating_5.score = 50
# rating_5.original_score = 50
# rating_5.user_id = user_id_4
# rating_5.publication_id = publication_id_2
# rating_5.save
#
# sm_strategy = RsmStrategy.new(rating_5)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_5)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_6 = Rating.new
# rating_6.score = 80
# rating_6.original_score = 80
# rating_6.user_id = user_id_4
# rating_6.publication_id = publication_id_1
# rating_6.save
#
# sm_strategy = RsmStrategy.new(rating_6)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_6)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# puts "########## GROUND_TRUTH_1 SIMULATION COMPLETED #########"

# puts "########## GROUND_TRUTH_2 SIMULATION STARTED #########"
#
# publication_id_1 = 1
# publication_id_2 = 2
# user_id_1 = 1
# user_id_2 = 2
# user_id_3 = 3
#
# rating_1 = Rating.new
# rating_1.score = 51
# rating_1.original_score = 51
# rating_1.user_id = user_id_1
# rating_1.publication_id = publication_id_1
# rating_1.save
#
# sm_strategy = RsmStrategy.new(rating_1)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_1)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_2 = Rating.new
# rating_2.score = 36
# rating_2.original_score = 36
# rating_2.user_id = user_id_1
# rating_2.publication_id = publication_id_2
# rating_2.save
#
# sm_strategy = RsmStrategy.new(rating_2)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_2)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_3 = Rating.new
# rating_3.score = 51
# rating_3.original_score = 51
# rating_3.user_id = user_id_2
# rating_3.publication_id = publication_id_1
# rating_3.save
#
# sm_strategy = RsmStrategy.new(rating_3)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_3)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_4 = Rating.new
# rating_4.score = 93
# rating_4.original_score = 93
# rating_4.user_id = user_id_2
# rating_4.publication_id = publication_id_2
# rating_4.save
#
# sm_strategy = RsmStrategy.new(rating_4)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_4)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_5 = Rating.new
# rating_5.score = 59
# rating_5.original_score = 59
# rating_5.user_id = user_id_3
# rating_5.publication_id = publication_id_1
# rating_5.save
#
# sm_strategy = RsmStrategy.new(rating_5)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_5)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# rating_6 = Rating.new
# rating_6.score = 3
# rating_6.original_score = 3
# rating_6.user_id = user_id_3
# rating_6.publication_id = publication_id_2
# rating_6.save
#
# sm_strategy = RsmStrategy.new(rating_6)
# readersourcing = Readersourcing.new(sm_strategy)
# readersourcing.compute_scores
#
# true_review_strategy = TrmStrategy.new(rating_6)
# readersourcing = Readersourcing.new(true_review_strategy)
# readersourcing.compute_scores
#
# puts "########## GROUND_TRUTH_2 SIMULATION COMPLETED #########"

puts "@@@@@@@@@@ SEEDING COMPLETED @@@@@@@@@@"


