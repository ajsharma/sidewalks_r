# Base class for all application mailers.
# Handles common email configuration and layouts.
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end
