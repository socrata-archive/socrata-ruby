Gem::Specification.new do |s|
  s.name = "socrata"
  s.version = "0.1.0"
  s.author = "Aiden Scandella"
  s.email = "aiden.scandella@socrata.com"
  s.homepage = "http://api.socrata.com/"
  s.summary = "Access the Socrata data platform via Ruby"
  s.description = "Access the Socrata data platform via Ruby"
  s.files = [
    "lib/socrata.rb",
    "lib/socrata/socrata_api.rb",
    "lib/socrata/dataset.rb",
    "lib/socrata/user.rb",
    "lib/socrata/config.yml"
    ]
  s.add_dependency('curb', '>= 0.5.4.0')
  s.add_dependency('json', '>= 1.1.6')
  s.add_dependency('httparty', '>= 0.4.3')
end
