class FabulatorContext < ActiveRecord::Base
  serialize :context
  belongs_to :page
  belongs_to :user

  def self.find_by_page(p)
    if p.request.session[:user_id].blank?
      c = self.first(:conditions => [
        'page_id = ? AND session = ? AND (user_id IS NULL OR user_id=0)',
        p.id, p.request.session[:session_id]
      ] )
    else
      c = self.first(:conditions => [
        'page_id = ? AND session = ? AND user_id = ?',
        p.id, p.request.session[:session_id], p.request.session[:user_id]
      ] )
    end
    if c.nil? && !p.request.session[:user_id].blank?
      c = self.first(:conditions => [
        'page_id = ? AND session = ?',
        p.id, p.request.session[:session_id]
      ] )
      if !c.nil? && c.user.nil?
        c.update_attribute(:user_id, p.request.session[:user_id])
      end
    end
    p.fabulator_context = c.context unless c.nil?
    return c unless c.nil?
    self.new(
      :context => p.fabulator_context,
      :page_id => p.id,
      :user_id => p.request.session[:user_id],
      :session => p.request.session[:session_id]
    )
  end
end
