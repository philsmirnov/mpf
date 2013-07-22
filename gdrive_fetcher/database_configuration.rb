require 'active_record'

settings = YAML.load_file('fetcher_settings.yml')

db_file_path = File.join(File.dirname(__FILE__), 'database.yml')
database = YAML::load_file(db_file_path)

env = settings['mode'] == 'dev' ? 'development' : 'production'

ActiveRecord::Base.establish_connection(database[env])
    :adapter => "postgresql",
    :host => "localhost",
    :database => "mps_development",
    :username => "vic"
)