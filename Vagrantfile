VAGRANTFILE_API_VERSION = "2"

path = "#{File.dirname(__FILE__)}"

require 'yaml'
require path + '/scripts/tender.rb'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  Tender.configure(config, YAML::load(File.read(path + '/Tender.yaml')))
end
