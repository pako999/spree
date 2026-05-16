puts "Creating admin user..."
AdminUser.find_or_create_by!(email: 'admin@racketrent.com') do |u|
  u.name = 'Admin'
  u.password = 'password123'
  u.role = 'admin'
  u.preferred_language = 'en'
end

puts "Creating club schedules..."
[
  { day_of_week: 1, opens_at: '08:00', closes_at: '21:00', label: 'Monday' },
  { day_of_week: 2, opens_at: '08:00', closes_at: '21:00', label: 'Tuesday' },
  { day_of_week: 3, opens_at: '08:00', closes_at: '21:00', label: 'Wednesday' },
  { day_of_week: 4, opens_at: '08:00', closes_at: '21:00', label: 'Thursday' },
  { day_of_week: 5, opens_at: '08:00', closes_at: '21:00', label: 'Friday' },
  { day_of_week: 6, opens_at: '09:00', closes_at: '18:00', label: 'Saturday' },
  { day_of_week: 0, opens_at: '00:00', closes_at: '00:00', closed: true, label: 'Sunday' }
].each do |attrs|
  ClubSchedule.find_or_create_by!(day_of_week: attrs[:day_of_week]) do |s|
    s.assign_attributes(attrs)
  end
end

puts "Creating racket types..."
tennis = RacketType.find_or_create_by!(name: 'Tennis Standard', category: 'tennis') do |t|
  t.price_per_day_cents = 1500
  t.description = 'Standard tennis racket rental'
end
tennis_pro = RacketType.find_or_create_by!(name: 'Tennis Pro', category: 'tennis') do |t|
  t.price_per_day_cents = 2500
  t.description = 'Professional tennis racket rental'
end
padel = RacketType.find_or_create_by!(name: 'Padel Standard', category: 'padel') do |t|
  t.price_per_day_cents = 1200
  t.description = 'Standard padel racket rental'
end
padel_pro = RacketType.find_or_create_by!(name: 'Padel Pro', category: 'padel') do |t|
  t.price_per_day_cents = 2000
  t.description = 'Professional padel racket rental'
end

puts "Creating sample rackets..."
[
  { racket_type: tennis, brand: 'Wilson', model: 'Blade 98' },
  { racket_type: tennis, brand: 'Babolat', model: 'Pure Drive' },
  { racket_type: tennis, brand: 'Head', model: 'Speed MP' },
  { racket_type: tennis_pro, brand: 'Wilson', model: 'Pro Staff RF97' },
  { racket_type: padel, brand: 'Bullpadel', model: 'Vertex 03' },
  { racket_type: padel, brand: 'Head', model: 'Alpha Pro' },
  { racket_type: padel_pro, brand: 'Babolat', model: 'Viper Air' }
].each do |attrs|
  Racket.find_or_create_by!(brand: attrs[:brand], model: attrs[:model]) do |r|
    r.racket_type = attrs[:racket_type]
  end
end

puts "Creating default email flow..."
EmailFlow.find_or_create_by!(name: 'We miss you') do |f|
  f.trigger_type = 'days_after_pickup'
  f.trigger_days = 90
  f.subject = {
    'en' => 'Time for fresh strings, {first_name}?',
    'de' => 'Zeit für neue Saiten, {first_name}?',
    'sl' => 'Čas za nove strune, {first_name}?'
  }
  f.body = {
    'en' => "<p>Hi {name},</p><p>It's been {days_since_stringing} days since your last stringing ({racket_model}). Your strings lose tension over time, which affects your game.</p><p>Come by for a fresh restring and feel the difference!</p>",
    'de' => "<p>Hallo {name},</p><p>Es sind {days_since_stringing} Tage seit Ihrer letzten Bespannung ({racket_model}). Ihre Saiten verlieren mit der Zeit an Spannung, was Ihr Spiel beeinflusst.</p><p>Kommen Sie für eine frische Bespannung vorbei!</p>",
    'sl' => "<p>Pozdravljeni {name},</p><p>Minilo je {days_since_stringing} dni od vašega zadnjega napenjanja ({racket_model}). Strune sčasoma izgubijo napetost, kar vpliva na vašo igro.</p><p>Pridite na novo napenjanje!</p>"
  }
end

puts "Seed complete!"
