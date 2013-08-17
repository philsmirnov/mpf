# encoding: UTF-8

module GDriveImporter

  class SpecialLinker < TextLinker

    def initialize(collections)
      super(collections, /\[\[.*?\]\[.*?\]\]/, [/(?<=\[\[).*?(?=\])/])
    end

    def process_links(text)
      super(text) do |links_array, raw_text|
        link_title = raw_text[/(?<=\]\[).*?(?=\])/]
        if links_array.empty?
          raw_text
        else
          item = links_array.first
          pf = item[:fof].parent_folder.title_for_save
          folder_title = pf =~ /glos/ ? 'glossariy' :  pf =~ /personali/ ? 'personalii' : "texts/#{pf}"
          "<%= link_to('#{link_title}',  '/#{folder_title}/#{item[:fof].title_for_save}.html') %>"
        end
      end
    end

  end

end
