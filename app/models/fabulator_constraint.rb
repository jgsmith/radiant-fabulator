class FabulatorConstraint < ActiveRecord::Base
  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  # handles running the constraint
  def run_constraint(params, field_names)
  end
end
