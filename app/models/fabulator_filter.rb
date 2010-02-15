class FabulatorFilter < ActiveRecord::Base
  # handle running the filter
  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  def before_save
    # compile constraint
    p = Fabulator::XSM::ExpressionParser.new
#    Rails.logger.info("Definition:  [#{self.definition}]")
    self.compiled_def = YAML::dump(p.parse(self.definition))
    true
  end

  # handles running the constraint
  def run(context)
    f = (YAML::Load(self.compiled_def) rescue nil)
    context.value = f.nil? ? nil : f.run(context)
    context.value = context.value.first if context.value.is_a?(Array) && context.value.size < 2
  end
end
