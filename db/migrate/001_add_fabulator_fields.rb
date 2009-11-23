class AddFabulatorFields < ActiveRecord::Migration
  def self.up
    add_column :pages, :compiled_xml, :text
  end

  def self.down
    remove_column :pages, :compiled_xml
  end
end
