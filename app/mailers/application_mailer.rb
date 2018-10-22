class ApplicationMailer < ActionMailer::Base
  default from: "#{I18n.t("mails.labels.platform_name")} <#{ENV['SENDGRID_USERNAME']}>"
  layout 'mailer'
end
