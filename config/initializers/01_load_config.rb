CONFIG = YAML.load_file(Rails.root.join('config', 'configuration.yml'))['defaults'].with_indifferent_access
