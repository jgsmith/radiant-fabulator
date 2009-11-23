class RdfStatement < ActiveRecord::Base
  belongs_to :rdf_model, :counter_cache => true

  belongs_to :subject, :class_name => 'RdfResource'
  belongs_to :predicate, :class_name => 'RdfResource'
  belongs_to :object, :polymorphic => true
#  belongs_to :rdf_language
#  belongs_to :rdf_type

  has_many :rdf_user_assertions # who asserted this fact?
  has_many :rdf_source_assertions # where did this come from?

  validates_presence_of :subject, :predicate, :object
end
