class CreateBlogs < ActiveRecord::Migration
  def self.up
    create_table :blogs do |t|
      t.string :name, :subdomain, :subtitle, :limit => 40
      t.integer :status, :rank, :permission, :adver
      t.text :description
      t.timestamps
    end
  end

  def self.down
    drop_table :blogs
  end
end
