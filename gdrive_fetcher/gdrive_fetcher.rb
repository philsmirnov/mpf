#!/usr/bin/env ruby
# encoding: UTF-8
require 'bundler'
require 'google_drive'
require 'awesome_print'
require 'htmlentities'

require 'yaml'
require 'active_support/core_ext/string/inflections'
require 'russian'
require 'thinking_sphinx'
require 'rest_client'
require 'optparse'


require_relative 'text_converter'
require_relative 'file_collection'
require_relative 'text_linker'
require_relative 'special_linker'
require_relative 'article_linker'
require_relative 'schema'
require_relative 'typograf_client'

Bundler.setup

I18n.locale = :'ru'
I18n.reload!

options = {:force_update => ['none']}
OptionParser.new do |opts|
  opts.banner = "Usage: gdrive_fetcher.rb [options]"
  opts.on('-n', '--no-full-update', 'No full update - use source from DB. Otherwise, default behaviour - fetch text from Google drive.') { options[:no_full_update] = true }
  opts.on('-u', '--force-update all,texts,personas,thesaurus', Array, 'Force update even if DB is up to date') { |v| options[:force_update] = v.map{|a| a.downcase} }
  opts.on('-s', '--skip-typograph', 'Skip typograph web service call') { |v| options[:skip_typograph] = true }
end.parse!

settings = YAML.load_file('fetcher_settings.yml').merge(options)

require 'pry' if settings[:mode] == 'dev'

#framework = ThinkingSphinx::Framework::Plain.new
#ThinkingSphinx::Configuration.instance.framework = framework

# You can also use OAuth. See document of
# GoogleDrive.login_with_oauth for details.
session = GoogleDrive.login(settings['mail'], settings['password'])

editable_text_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0ByqVdNbTHZeOU09jVEtxNklOSEE?v=3')

coder = HTMLEntities.new
typograf = TypografClient.new(settings[:skip_typograph], IO.read('typograph.xml'))
collection = GDriveImporter::FileCollection.new(editable_text_collection, coder)

text_converter = GDriveImporter::TextConverter.new
root_path ='./source/texts'

text_linker = GDriveImporter::TextLinker.new(
    [collection],
    /(?<=\()\s?с[рм]\.?[^\)]*?(?=\))/im,
    [/["«“]([^"»”]*?)["»”]/, /с[мр]\.?[[:space:]]*?(.*)/i]
)

thesaurus_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0B_j0BZPW4BVtR09BMXg3TFhJbG8?v=3')
thesaurus = GDriveImporter::Folder.new(thesaurus_collection, coder)
thesaurus.import

personas_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0B_j0BZPW4BVtMjMzcmVhTktiUFE?v=3')
personas = GDriveImporter::Folder.new(personas_collection, coder)
personas.import

special_linker = GDriveImporter::SpecialLinker.new([collection, thesaurus, personas])

article_linker = GDriveImporter::ArticleLinker.new([thesaurus, personas])

see_also_linker = GDriveImporter::TextLinker.new(
    [thesaurus, personas],
    /(?<=<p>см. также:|ср\.:).*?(?=<\/p>)/i,
    [/(?<=<em class="underline">).*?(?=<\/em>)/i, /([^,]*)/i]
)


should_force_update = !(%w(all texts) & settings[:force_update]).empty?

collection.files.each do |file|

  Article.db_saver(file, 'text', should_force_update) do |a|
    if a && settings[:no_full_update]
      file.original_contents = a.source
    else
      file.fetch
    end

    text_converter.convert file

    found_articles = special_linker.process_links(file.contents)

    text_linker.process_links(file.contents) do |links_array|
      'см. ' + links_array.map { |item|
        item[:fof].link_to(item[:title])
      }.join(', ')
    end

    see_also_linker.process_links(file.contents) do |links_array|
      file.set_linked_articles(links_array)
      nil
    end

    found_articles.concat article_linker.process_links(file.contents)
    if file.has_no_linked_articles
      file.set_linked_articles(found_articles)
    end

    file.contents = file.contents.
        sub('<p>См. также:</p>', ' ').
        sub('<p>Тексты на тему:</p>', ' ')

    file.contents = file.contents.gsub(/\[image=(.*?)\]/, '<%= picture \'\\1\' %>')

    #LEAD
    if file.contents =~ /LEAD(.*?)LEAD/
      file.first_paragraph = file.contents.match(/LEAD(.*?)LEAD/)[1]
    end
    file.contents = typograf.typografy(file.contents)
    sleep 1 unless settings[:skip_typograph]
  end
end

collection.files.each do |file|
  path = file.parent_folder.generate_path(root_path)
  path.mkpath
  file.save(path + file.generate_filename)
end

home = {'title' => 'Оглавление'}
chapters = []

collection.each do |folder|
  path = Pathname(root_path) + folder.title_for_save + 'index.html.erb'
  f = File.new(path, 'w+')
  content_table = folder.content_table
  f.write(content_table)
  f.close

  intro = begin folder.files.find { |f| f =~ /intro/i }.fetch_text rescue nil end

  chapter = {
      :roman_number => RomanNumerals.to_roman(folder.number),
      :number => folder.number,
      :title => folder.title,
      :intro => intro || 'Пока еще не написано',
      :title_for_save => folder.title_for_save,
      :files => folder.map do |file|
        {
            :title_for_save => "#{folder.title_for_save}/#{file.title_for_save}.html",
            :number => file.number,
            :title => file.title,
            :first_paragraph => file.first_paragraph
        }
      end
  }

  chapters << chapter
end

home[:chapters] = chapters
f = File.new('./data/home.yml', 'w+')
f.write(home.to_yaml)
f.close

text_linker = GDriveImporter::TextLinker.new(
    [collection],
    /(?<=Тексты на тему:<\/p>).(.*)/im,
    [/(?<=<p>)(.*?)(?=<\/p>)/]
)

root_path = './source/'
path = personas.generate_path(root_path)
path.mkpath

should_force_update = !(%w(all personas) & settings[:force_update]).empty?

personas.
#    take(2).
    each do |file|
  Article.db_saver(file, 'persona', should_force_update) do |a|
    if a && settings[:no_full_update]
      file.original_contents = a.source
    else
      file.fetch
    end
    text_converter.convert(file)
    file.contents = file.contents.sub(/^<p>.*?<\/p>/, '').strip
    file.metadata[:years] = file.first_paragraph
    file.first_paragraph = file.contents[/^<p>.*?<\/p>/].gsub(/^<p>(.*?)<\/p>/, '\\1')

    found_articles = special_linker.process_links(file.contents)

    text_linker.process_links(file.contents) do |links_array|
      file.metadata[:linked_texts] = links_array.map do |item|
        {
            :link => item[:fof].link_to(item[:title]),
            :first_paragraph => item[:fof].respond_to?(:first_paragraph) ? item[:fof].first_paragraph : nil
        }
      end
      nil
    end

    see_also_linker.process_links(file.contents) do |links_array|
      file.set_linked_articles(links_array)
      nil
    end

    found_articles.concat article_linker.process_links(file.contents)
    if file.has_no_linked_articles
      file.set_linked_articles(found_articles)
    end

    file.contents = file.contents.
        sub('<p>См. также:</p>', ' ').
        sub('<p>Тексты на тему:</p>', ' ')

    file.contents = typograf.typografy(file.contents)
    file.show_next_three = false
    sleep 1 unless settings[:skip_typograph]
  end
  file.show_next_three = false
  file.save(path + file.generate_filename)
end

personas_yaml = {'title' => 'Персоналии'}
groups = []

personas.each_slice(3) do |group_of_files|
  groups << group_of_files.map do |file|
    {
        :link => "#{personas.title_for_save}/#{file.title_for_save}.html",
        :title => file.title,
        :first_line => file.first_paragraph,
        :years => file.metadata[:years]
    }
  end
end

personas_yaml['groups'] = groups
f = File.new('./data/personas.yml', 'w+')
f.write(personas_yaml.to_yaml)
f.close

root_path = './source/'
path = thesaurus.generate_path(root_path)
path.mkpath

should_force_update = !(%w(all thesaurus) & settings[:force_update]).empty?

thesaurus.
#    drop(3).
#    take(1).
    each do |file|
  Article.db_saver(file, 'thesaurus', should_force_update) do |a|
    if a && settings[:no_full_update]
      file.original_contents = a.source
    else
      file.fetch
    end
    text_converter.convert(file)

    #убираем отбивку
    file.contents.sub!('</p> <p>', '')

    found_articles = special_linker.process_links(file.contents)

    text_linker.process_links(file.contents) do |links_array|
      file.metadata[:linked_texts] = links_array.map do |item|
        {
            :link => item[:fof].link_to(item[:title]),
            :first_paragraph => item[:fof].respond_to?(:first_paragraph) ? item[:fof].first_paragraph : nil
        }
      end
      nil
    end

    see_also_linker.process_links(file.contents) do |links_array|
      file.set_linked_articles(links_array)
      nil
    end

    found_articles.concat article_linker.process_links(file.contents)
    if file.has_no_linked_articles
      file.set_linked_articles(found_articles)
    end

    file.contents = file.contents.
        sub('<p>См. также:</p>', ' ').
        sub('<p>Тексты на тему:</p>', ' ').
        sub('<p>Cр.:</p>', ' ')


    file.contents = typograf.typografy(file.contents)
    #file.first_paragraph = file.contents[/^<p>.*?<\/p>/].gsub(/^<p>(.*?)<\/p>/, '\\1')
    file.show_next_three = false
    sleep 1 unless settings[:skip_typograph]
  end
  file.show_next_three = false
  file.save(path + file.generate_filename)
end

thesaurus_yaml = {'title' => 'Тезаурус'}
groups = []

thesaurus.each_slice(3) do |group_of_files|

  groups << group_of_files.map do |file|
    {
        :link => "#{thesaurus.title_for_save}/#{file.title_for_save}.html",
        :title => file.title,
        :first_line => file.first_paragraph,
        :linked_articles_count => (file.metadata[:linked_texts]||[]).count,
    }
  end
end

thesaurus_yaml['groups'] = groups
f = File.new('./data/tezaurus.yml', 'w+')
f.write(thesaurus_yaml.to_yaml)
f.close
