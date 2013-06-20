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


Bundler.setup

I18n.locale = :'ru'
I18n.reload!

settings = YAML.load_file('fetcher_settings.yml')

# You can also use OAuth. See document of
# GoogleDrive.login_with_oauth for details.
session = GoogleDrive.login(settings['mail'], settings['password'])

editable_text_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0ByqVdNbTHZeOU09jVEtxNklOSEE?v=3')

coder = HTMLEntities.new
collection = GDriveImporter::FileCollection.new(editable_text_collection, coder)
text_converter = GDriveImporter::TextConverter.new

text_converter = GDriveImporter::TextConverter.new
root_path ='./source/texts'

text_linker = GDriveImporter::TextLinker.new(
    collection,
    /(?<=\()\s?с[рм]\.?[^\)]*?(?=\))/im,
    [/["«“]([^"»”]*?)["»”]/, /с[мр]\.?[[:space:]]*?(.*)/i]
)

i = 0
collection.each_file do |file|
  i += 1
  #break if i > 2

  puts "#{file.number} #{file.title}"
  file.fetch
  file.save_original "./gdrive_fetcher/gdrive_originals/google_#{file.title}.html" if settings['mode'] == 'dev'

  text_converter.convert file

  path = file.parent_folder.generate_path(root_path)

  text_linker.process_links(file) do |links_array|
    'см. ' + links_array.map { |item|
      item[:fof].link_to(file, item[:title])
    }.join(', ')
  end
  path.mkpath
  file.save(path + file.generate_filename)
  sleep 1
end


home = {'title' => 'Содержание'}
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
            :title => file.title
        }
      end
  }

  chapters << chapter
end

home[:chapters] = chapters
f = File.new('./data/home.yml', 'w+')
f.write(home.to_yaml)
f.close


thesaurus_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0B_j0BZPW4BVtR09BMXg3TFhJbG8?v=3')
thesaurus = GDriveImporter::Folder.new(thesaurus_collection, coder)
thesaurus.import

text_linker = GDriveImporter::TextLinker.new(
    collection,
    /(?<=Тексты на тему:<\/p>).(.*)/im,
    [/(?<=<p>)(.*?)(?=<\/p>)/]
)

article_linker = GDriveImporter::TextLinker.new(
    thesaurus,
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
  file.save_original "./gdrive_fetcher/gdrive_originals/google_#{file.title}.html" if settings['mode'] == 'dev'
  text_converter.convert(file)

  #убираем отбивку
  file.contents.sub!('</p> <p>', ' ')

  text_linker.process_links(file) do |links_array|
    file.metadata[:linked_texts] = links_array.map do |item|
      {
          :link => item[:fof].link_to(file, item[:title], 'texts'),
          :first_paragraph => item[:fof].respond_to?(:first_paragraph) ? item[:fof].first_paragraph : nil
      }
    end
    nil
  end

  article_linker.process_links(file) do |links_array|
    file.metadata[:linked_articles] = links_array.map do |item|
      {
          :link => item[:fof].link_to(file, item[:title]),
          :first_paragraph => item[:fof].respond_to?(:first_paragraph) ? item[:fof].first_paragraph : nil
      }
    end
    nil
  end

  file.contents = file.contents.sub('<p>См. также:</p>', ' ').sub('<p>Тексты на тему:</p>', ' ')

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

personas_collection = session.collection_by_url('https://docs.google.com/feeds/default/private/full/folder%3A0B_j0BZPW4BVtMjMzcmVhTktiUFE?v=3')
personas = GDriveImporter::Folder.new(personas_collection, coder)
personas.import

text_linker = GDriveImporter::TextLinker.new(
    collection,
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
  file.save_original "./gdrive_fetcher/gdrive_originals/google_#{file.title}.html" if settings['mode'] == 'dev'
  text_converter.convert(file)

  #убираем отбивку
  #file.contents.sub!('</p> <p>', ' ')

  text_linker.process_links(file) do |links_array|
    links_array.map { |item| "<p>#{item[:fof].link_to(file, item[:title], 'texts')} </p>" }.join("\n")
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
