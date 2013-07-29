require_relative 'database_configuration'

class Article < ActiveRecord::Base
  record_timestamps = false
  skip_time_zone_conversion_for_attributes = [:updated_at]

  def self.create_or_update(file, article_type, base_url)
    a = Article.where(:resource_id => file.resource_id).first
    if a
      # update if needed
      if a.updated_at < file.updated_at
        a.content = file.fetch_text
        a.updated_at = file.updated_at
      end
    else
      # save to db
      a = Article.from_file(file, article_type, base_url)
    end
    a.save
  end

  def self.from_file(file, article_type, base_url)
    self.new(
        :resource_id => file.resource_id,
        :name => file.title,
        :resource_type => file.resource_type,
        :content => file.fetch_text,
        :updated_at => file.updated_at,
        :article_type => article_type,
        :url => article_type == 'text' ?
            "#{file.parent_folder.title_for_save}/#{file.title_for_save}.html" :
            "#{file.title_for_save}.html"
    )
  end
end