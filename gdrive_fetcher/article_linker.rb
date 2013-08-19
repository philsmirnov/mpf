# encoding: UTF-8

require 'thinking_sphinx'


module GDriveImporter

  class ArticleLinker < TextLinker

    def initialize(collections)
      main_regexp =/<em class="underline">.*?<\/em>/i
      name_regexps = [/(?<=<em class="underline">).*?(?=<\/em>)/i]

      super(collections, main_regexp, name_regexps) do |link_title|
        link_title = link_title.gsub(/[[:space:]]{1,4}/, ' ')
        regexp_text = ::ThinkingSphinx::Connection.take { |con| con.execute "CALL KEYWORDS('#{link_title}', 'article_core')"}.
            map {|result| result['normalized'].encode('ISO-8859-1').force_encoding('UTF-8')}.
            map{|w| Regexp.escape(w) + '.{0,7}'}.
            join('')
        regexp = Regexp.new(regexp_text, 'i')
        puts regexp
        regexp
      end
    end

    def process_links(text)
      found_articles = []
      super(text) do |links_array, raw_text|
        if links_array.empty?
          raw_text
        else
          item = links_array.first
          found_articles << item
          folder_title = item[:fof].parent_folder.title_for_save =~ /glos/ ? 'glossariy' : 'personalii'
          "<%= link_to('#{raw_text}',  '/#{folder_title}/#{item[:fof].title_for_save}.html') %>"
        end
      end
      found_articles
    end

  end

end
