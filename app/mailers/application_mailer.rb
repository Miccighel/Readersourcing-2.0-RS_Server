class ApplicationMailer < ActionMailer::Base

  default from: "#{I18n.t("mails.labels.platform_name")} <#{ENV['EMAIL_ADMIN']}>"
  layout 'mailer'

  def send_message(mail, message)
    @mail = mail
    @message = message
    mail(
        to: "Readersourcing Team - <#{ENV['EMAIL_ADMIN']}>",
        subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.contact_message")}",
        :template_path => 'application',
        :template_name => 'mails/message'
    )
  end

  def report(mail, message)
    @mail = mail
    @message = message
    mail(
        to: "Readersourcing Team - <#{ENV['EMAIL_BUG_REPORT']}>",
        subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.bug_report")}",
        :template_path => 'application',
        :template_name => 'mails/report'
    )
  end

end
