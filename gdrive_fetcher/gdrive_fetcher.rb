# encoding: UTF-8
require 'bundler'
require 'google_drive'
require 'awesome_print'
require 'htmlentities'
require 'pry'
require 'yaml'
require 'active_support/core_ext/string/inflections'
require 'russian'

require_relative 'text_converter'
require_relative 'file_collection'
require_relative 'text_linker'
require_relative 'schema'
require 'thinking_sphinx'
require 'rest_client'

Bundler.setup

I18n.locale = :'ru'
I18n.reload!

settings = YAML.load_file('fetcher_settings.yml')
typograph_settings = IO.read('typograph.xml')

#framework = ThinkingSphinx::Framework::Plain.new
#ThinkingSphinx::Configuration.instance.framework = framework

# You can also use OAuth. See document of
# GoogleDrive.login_with_oauth for details.
session = GoogleDrive.login(settings['mail'], settings['password'])

editable_text_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0ByqVdNbTHZeOU09jVEtxNklOSEE?v=3')

coder = HTMLEntities.new
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


article_linker = GDriveImporter::TextLinker.new(
    [thesaurus, personas],
    /<em class="underline">.*?<\/em>/i,
    [/(?<=<em class="underline">).*?(?=<\/em>)/i]
) do |link_title|
  link_title = Unicode::normalize_C(coder.decode(link_title)).gsub(/[[:space:]]{1,4}/, ' ')
  regexp_text = ThinkingSphinx::Connection.take { |con| con.execute "CALL KEYWORDS('#{link_title}', 'article_core')"}.
      map {|res| res['normalized'].encode('ISO-8859-1').force_encoding('UTF-8')}.
      map{|w| Regexp.escape(w) + '.{0,7}'}.
      join('')
  regexp = Regexp.new(regexp_text, 'i')
  puts regexp
  regexp
end

collection.files.each do |file|
  puts "#{file.number} #{file.title}"
  file.fetch
  Article.create_or_update(file, 'text', settings['base_url'])

  file.save_original "./gdrive_fetcher/gdrive_originals/google_#{file.title}.html" if settings['mode'] == 'dev'

  text_converter.convert file
  file.contents = RestClient.post('http://typograf.ru/webservice/', :text => file.contents, :chr => 'UTF-8', :xml => typograph_settings)

  text_linker.process_links(file) do |links_array|
    'см. ' + links_array.map { |item|
      item[:fof].link_to(file, item[:title])
    }.join(', ')
  end

  article_linker.process_links(file) do |links_array, raw_text|
    if links_array.empty?
      raw_text
    else
      item = links_array.first
      folder_title = item[:fof].parent_folder.title_for_save =~ /glos/ ? 'glossariy' : 'personalii'
      "<%= link_to('#{raw_text}',  '/#{folder_title}/#{item[:fof].title_for_save}.html') %>"
    end
  end

  #LEAD
  if file.contents =~ /LEAD(.*?)LEAD/
    file.first_paragraph = file.contents.match(/LEAD(.*?)LEAD/)[1]
  end

  sleep 1
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

  chapter = {
      :roman_number => RomanNumerals.to_roman(folder.number),
      :number => folder.number,
      :title => folder.title,
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

personas.
#    take(2).
    each do |file|
  puts "#{file.number} #{file.title}"
  file.fetch
  Article.create_or_update(file, 'persona', settings['base_url'])
  file.save_original "./gdrive_fetcher/gdrive_originals/google_#{file.title}.html" if settings['mode'] == 'dev'
  text_converter.convert(file)
  file.contents = RestClient.post('http://typograf.ru/webservice/', :text => file.contents, :chr => 'UTF-8', :xml => typograph_settings)

  text_linker.process_links(file) do |links_array|
    links_array.map { |item| "<p>#{item[:fof].link_to(file, item[:title], 'texts')} </p>" }.join("\n")
  end

  article_linker.process_links(file) do |links_array, raw_text|
    if links_array.empty?
      raw_text
    else
      item = links_array.first
      item[:fof].link_to(file, item[:title])
    end
  end

  file.show_next_three = false
  file.save(path + file.generate_filename)
  sleep 1
end

personas_yaml = {'title' => 'Персоналии'}
groups = []

personas.each_slice(3) do |group_of_files|
  groups << group_of_files.map do |file|
    {
        :link => "#{personas.title_for_save}/#{file.title_for_save}.html",
        :title => file.title,
        :first_line => file.first_paragraph
    }
  end
end

personas_yaml['groups'] = groups
f = File.new('./data/personas.yml', 'w+')
f.write(personas_yaml.to_yaml)
f.close

text_linker = GDriveImporter::TextLinker.new(
    [collection],
    /(?<=Тексты на тему:<\/p>).(.*)/im,
    [/(?<=<p>)(.*?)(?=<\/p>)/]
)

second_article_linker = GDriveImporter::TextLinker.new(
    [thesaurus],
    /(?<=<p>см. также:|ср\.:).*?(?=<\/p>)/i,
    [/(?<=<em class="underline">).*?(?=<\/em>)/i,
    /([^,]*)/i]
)

root_path = './source/'
path = thesaurus.generate_path(root_path)
path.mkpath

thesaurus.
#    drop(3).
#    take(1).
    each do |file|
  puts "#{file.number} #{file.title}"
  file.fetch
  Article.create_or_update(file, 'thesaurus', settings['base_url'])
  file.save_original "./gdrive_fetcher/gdrive_originals/google_#{file.title}.html" if settings['mode'] == 'dev'
  text_converter.convert(file)

  #убираем отбивку
  file.contents.sub!('</p> <p>', ' ')
  file.contents = RestClient.post('http://typograf.ru/webservice/', :text => file.contents, :chr => 'UTF-8', :xml => typograph_settings)

  text_linker.process_links(file) do |links_array|
    file.metadata[:linked_texts] = links_array.map do |item|
      {
          :link => item[:fof].link_to(file, item[:title], 'texts'),
          :first_paragraph => item[:fof].respond_to?(:first_paragraph) ? item[:fof].first_paragraph : nil
      }
    end
    nil
  end

  article_linker.process_links(file) do |links_array, raw_text|
    if links_array.empty?
      raw_text
    else
      item = links_array.first
      item[:fof].link_to(file, item[:title])
    end
  end

  second_article_linker.process_links(file) do |links_array|
    file.metadata[:linked_articles] = links_array.map do |item|
      {
          :link => item[:fof].link_to(file, item[:title]),
          :first_paragraph => item[:fof].respond_to?(:first_paragraph) ? item[:fof].first_paragraph : nil
      }
    end
    nil
  end


  file.contents = file.contents.
      sub('<p>См. также:</p>', ' ').
      sub('<p>Тексты на тему:</p>', ' ').
      sub('<p>Cр.:</p>', ' ')

  file.show_next_three = false
  file.save(path + file.generate_filename)
  sleep 1
end

thesaurus_yaml = {'title' => 'Тезаурус'}
groups = []

thesaurus.each_slice(3) do |group_of_files|

  groups << group_of_files.map do |file|
    {
        :link => "#{thesaurus.title_for_save}/#{file.title_for_save}.html",
        :title => file.title,
        :first_line => file.first_paragraph
    }
  end
end

thesaurus_yaml['groups'] = groups
f = File.new('./data/tezaurus.yml', 'w+')
f.write(thesaurus_yaml.to_yaml)
f.close


