CONFIG_PATH="#{Rails.root}/config/config.yml"
APP_CONFIG = YAML.load_file(CONFIG_PATH)[Rails.env]
APP_CONFIG["rs_pdf"] = "#{Rails.root}/lib/#{APP_CONFIG["lib_name"]}"