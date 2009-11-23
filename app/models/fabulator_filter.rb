class FabulatorFilter < ActiveRecord::Base
  # handle running the filter
  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  def run_filter(params, fields)
  end
end
