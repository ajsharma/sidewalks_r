# Base class for all application models.
# Provides common ActiveRecord functionality and configurations.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
