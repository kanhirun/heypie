daiv = Grunt.find_or_create_by!(name: "U1UESB3TP") # daiv
kel = Grunt.find_or_create_by!(name: "U1UGEND33") # kel
justin = Grunt.find_or_create_by!(name: "UCBMB4W3C") # justin
chip = Grunt.find_or_create_by!(name: "UCD1YB1E2") # chip
vu = Grunt.find_or_create_by!(name: "UCBRKETRT") # vu

daiv.slices_of_pie = 400
daiv.save!

kel.slices_of_pie = 800
kel.save!

justin.slices_of_pie = 350
justin.save!

vu.slices_of_pie = 275
vu.save!

chip.slices_of_pie = 150
chip.save!
