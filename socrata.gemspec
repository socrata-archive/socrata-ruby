Gem::Specification.new do |s|
  s.name = "socrata"
  s.version = "0.1.6"
  s.author = "Chris Metcalf"
  s.email = "chris.metcalf@socrata.com"
  s.homepage = "http://dev.socrata.com/"
  s.summary = "Access the Socrata data platform via Ruby"
  s.description = "Access the Socrata data platform via Ruby"
  s.files = [
    "lib/socrata.rb",
    "lib/socrata/data.rb",
    "lib/socrata/user.rb"
    ]
  s.add_dependency('curb', '>= 0.5.4.0')
  s.add_dependency('json', '>= 1.1.6')
  s.add_dependency('httparty', '>= 0.4.3')
end
