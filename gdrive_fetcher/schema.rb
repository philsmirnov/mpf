require_relative 'database_configuration'

class Article < ActiveRecord::Base
  record_timestamps = false
  skip_time_zone_conversion_for_attributes = [:updated_at]

  def needs_update?(updated_at)
    self.updated_at < updated_at
  end

  def update_from_file(file)
    self.source = file.original_contents
    self.content = file.fetch_text
    self.updated_at = file.updated_at
    self.result = file.contents
    self.metadata = file.metadata.to_yaml
  end

  def save_to_file(file)
    file.original_contents = source
    file.contents = result
    file.metadata = YAML.load(metadata)
  end

  def self.get_by_resource_id(resource_id)
    Article.where(:resource_id => resource_id).first
  end

  def self.create_or_update(file, article_type)
    a = Article.where(:resource_id => file.resource_id).first
    if a
      # update if needed
      if a.needs_update?(file.updated_at)
        a.update_from_file(file)
      end
    else
      # save to db
      a = Article.create_from_file(file, article_type)
    end
    a.save
  end

  def self.create_from_file(file, article_type)
    self.new(
        :resource_id => file.resource_id,
        :name => file.title,
        :resource_type => file.resource_type,
        :source => file.original_contents,
        :content => file.fetch_text,
        :result => file.contents,
        :metadata => file.metadata.to_yaml,
        :updated_at => file.updated_at,
        :article_type => article_type,
        :url => article_type == 'text' ?
            "#{file.parent_folder.title_for_save}/#{file.title_for_save}.html" :
            "#{file.title_for_save}.html"
    )
  end

  def self.save_result
    a = Article.where(:resource_id => file.resource_id).first
    if a
      a.content = file.fetch_text
      a.result = file.contents
      a.metadata = file.metadata.to_yaml
    end
  end

  def self.db_saver(file, article_type, force_update = false)
    puts "#{file.number} #{file.title}"
    a = Article.get_by_resource_id file.resource_id

    if (a && a.needs_update?(file.updated_at)) || !a || force_update
      yield
      file.generate_metadata
      if a
        puts "'#{file.title}' needed update: #{a.updated_at} < #{file.updated_at}"
        a.update_from_file(file)
      else
        puts "'#{file.title}' was not in the database"
        a = Article.create_from_file(file, article_type)
      end
      a.save
      sleep 1
    else
      a.save_to_file(file)
    end
  end


end