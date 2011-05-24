class FabulatorExtension
  class Archive < Fabulator::Radiant::Archive
    namespace Fabulator::FAB_NS
    version   0.9
    
    writing do
      folder :public, '/images/assets'
      
      # we return data structures to be encoded with JSON
      
      ### Radiant core data
      data :config, Config
      
      ### Users
      data :users, User
      
      ### Content
      data :layouts, Layout
      
      data :pages, Page do |io|
        # write out pages/page parts for non-Fabulator pages
        Page.find(:all, :conditions => ["class_name != ?", 'FabulatorPage']).each do |p|
          attrs = p.attributes
          attrs[:parts] = p.page_parts.inject({}) { |parts, pp| 
            ppattrs = pp.attributes
            ppattrs[:filter] = ppattrs[:filter_id]
            ppattrs.delete(:filter_id)
            parts[ppattrs[:name].to_sym] = ppattrs
            parts
          }
          io << attrs
        end
      end
      
      data :applications do |io|
        Page.find(:all, :conditions => ["class_name = ?", 'FabulatorPage']).each do |p|
          attrs = p.attributes
          attrs[:parts] = p.page_parts.inject({}) { |parts, pp| 
            ppattrs = pp.attributes
            ppattrs[:filter] = ppattrs[:filter_id]
            ppattrs.delete(:filter_id)
            parts[ppattrs[:name].to_sym] = ppattrs
            parts
          }
          extended = attrs[:parts][:extended]
          if !extended.nil?
            attrs[:parts].delete(:extended)
            attrs[:xml] = extended[:content]
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
      
      ### Fabulator extensions
      data :libraries, FabulatorLibrary
    end
    
    reading do
      ### Radiant core data
      data :config do
        # :key
        # :value
        # :description
      end
      
      data :extensions do
        # :name
        # :schema_version
        # :enabled
      end
      
      ### Users
      data :users do
        # :id
        # :name
        # :email
        # :login
        # :password
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
        # :admin
        # :designer
        # :notes
        # :salt
        # :session_token
        # :locale
      end
      
      ### Content
      data :layouts do
        # :id
        # :name
        # :content
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
        # :content_type
      end
      
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

      data :snippets do
        # :name
        # :filter
        # :content
        # :created_at
        # :updated_at
        # :created_by_id
        # :updated_by_id
      end
      
      data :assets do
        # write out assets data
        # :id
        # :caption
        # :title
        # :asset_file_name
        # :asset_content_type
        # :asset_file_size
        # :created_by_id
        # :updated_by_id
        # :created_at
        # :updated_at
      end
      
      data :page_attachments do
        # :asset_id
        # :page_id
        # :position
      end
      
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
      
      ### Fabulator extensions
      data :libraries do |io|
        # write out libraries
        FabulatorLibrary.find.each do |lib|
          io << {
            :id => lib.id,
            :name => lib.name,
            :xml => lib.xml,
            :updated_by => lib.updated_by.id,
            :created_by => lib.created_by.id,
            :created_at => lib.created_at,
            :updated_at => lib.updated_at
          }
        end
      end
    end
  end
end