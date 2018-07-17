# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

puts "---------- SEEDING STARTED ----------"

Publication.create([{doi: "10.1038/nphys1170", title: "Quantum tomography: Measured measurement"}])
Publication.create([{doi: "10.1002/0470841559.ch1", title: "Internetworking LANs and WANs (Second Edition)"}])

puts "---------- SEEDING COMPLETED ----------"