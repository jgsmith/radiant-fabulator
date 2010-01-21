class FabulatorConstraint < ActiveRecord::Base
  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  def before_save
    # compile constraint
    p = Fabulator::XSM::ExpressionParser.new
    self.compiled_fn = YAML::Dump(p.compile(self.fn))
  end

  # handles running the constraint
  def run_constraint(context)
    f = (YAML::Load(self.compiled_fn) rescue nil)
    return false if f.nil?
    result = f.run(context)
    return false if result.nil? || result.empty? || !result.first
    return true
  end
end
