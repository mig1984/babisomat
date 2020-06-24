if ENV['ENVIRONMENT'].to_s.empty?
  raise "no ENVIRONMENT variable set"
end

if ENV['DATABASE_URL'].to_s.empty?
  raise "no DATABASE_URL variable set"
end

DATABASE_URL = ENV['DATABASE_URL']

# used in models/upload cols to define set of types in one place

IMG_DEFINITIONS = {
  :default => [proc {im_resize(200, 200, '^')}, 'jpg'],
  :thumb   => [proc {im_resize(200, 200, '^')}, 'jpg'],
  :big     => [proc {im_resize(1000, nil, '^')}, 'jpg']
}
