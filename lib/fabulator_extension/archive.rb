require 'fabulator/radiant/archive'

class FabulatorExtension
  class Archive < Fabulator::Radiant::Archive
    namespace Fabulator::FAB_NS
    version   0.9
    
    writing do
      folder :public, '/images/assets'
      
      # we return data structures to be encoded with JSON
      
      ### Radiant core data
      data :config, Radiant::Config
      
      ### Users
      data :users, User
      
      ### Content
      data :layouts, Layout
      
      data :pages do |io|
        # write out pages/page parts for non-Fabulator pages
        Page.find(:all, :conditions => ["class_name != ?", 'FabulatorPage']).each do |p|
          attrs = p.attributes
          attrs["parts"] = p.parts.inject({}) { |parts, pp| 
            ppattrs = pp.attributes
            ppattrs["filter"] = ppattrs["filter_id"]
            ppattrs.delete("filter_id")
            nom = ppattrs["name"]
            ppattrs.delete("name")
            parts[nom] = ppattrs
            parts
          }
          io << attrs
        end
      end
      
      data :applications do |io|
        Page.find(:all, :conditions => ["class_name = ?", 'FabulatorPage']).each do |p|
          attrs = p.attributes
          attrs.delete("class_name")
          attrs.delete("compiled_xml")
          attrs["parts"] = p.parts.inject({}) { |parts, pp| 
            ppattrs = pp.attributes
            ppattrs["filter"] = ppattrs["filter_id"]
            ppattrs.delete("filter_id")
            nom = ppattrs["name"]
            ppattrs.delete("name")
            parts[nom] = ppattrs
            parts
          }
          extended = attrs["parts"]["extended"]
          if !extended.nil?
            attrs["parts"].delete("extended")
            attrs["xml"] = extended["content"]
          end
          io << attrs
        end
      end

      data :snippets, Snippet, {
        :filter => :filter_id
      }
      
      data :assets, Asset
      
      data :page_attachments, PageAttachment
      
      data :js do |io|
        
        # write out javascripts
        # :class_name (distinguishing between :js and :css)
        # :name
        # :content
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
        # :filter
        # :minify (boolean)
      end
      
      data :css do
        # write out stylesheets
        # :class_name (distinguishing between :js and :css)
        # :name
        # :content
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
        # :filter
        # :minify (boolean)
      end
      
      data :libraries, FabulatorLibrary
    end
    
    reading do
      
      ### Radiant core data
      data :config, Radiant::Config
      
      ### Users
      data :users, User
      
      ### Content
      data :layouts, Layout
      
      data :pages do
        # write out pages/page parts for non-Fabulator pages
        # :title
        # :slug
        # :breadcrumb
        # :class_name
        # :status_id
        # :parent_id
        # :layout_id
        # :created_at
        # :updated_at
        # :published_at
        # :created_by_id
        # :updated_by_id
        # :virtual
        # :description
        # :keywords
        # :parts => [ {
        #   :name
        #   :filter
        #   :content
        # }]
      end
      
      data :applications do
        # write out pages/page parts for Fabulator pages
        # :title
        # :slug
        # :breadcrumb
        # :status_id
        # :parent_id
        # :layout_id
        # :created_at
        # :updated_at
        # :published_at
        # :created_by_id
        # :updated_by_id
        # :virtual
        # :description
        # :keywords
        # :xml
        # :views => [ {
        #   :name
        #   :filter
        #   :content
        # }]
      end

      data :snippets, Snippet, {
        :filter_id => :filter
      }
      
      data :assets, Asset
      
      data :page_attachments, PageAttachment
      
      data :js do
        # write out javascripts
        # :class_name (distinguishing between :js and :css)
        # :name
        # :content
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
        # :filter
        # :minify (boolean)
      end
      
      data :css do
        # write out stylesheets
        # :class_name (distinguishing between :js and :css)
        # :name
        # :content
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
        # :filter
        # :minify (boolean)
      end
      
      data :libraries, FabulatorLibrary
    end
  end
end