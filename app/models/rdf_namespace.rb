class RdfNamespace < ActiveRecord::Base
  validates_presence_of :namespace
  validates_uniqueness_of :namespace

  has_many :rdf_resources

  def [](ln)
    r = (self.rdf_resources.first(:conditions => [ 'local_name = ?', ln ]) rescue nil)
    if r.nil?
      r = self.rdf_resources.build({
        :local_name => ln
      });
    end
    r
  end

  def to_s
    namespace
  end
end
