ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load .env file
env_file = File.expand_path("../../.env", __FILE__)
if File.exist?(env_file)
  File.foreach(env_file) do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    key, value = line.split('=', 2)
    ENV[key] ||= value if key && value
  end
end
