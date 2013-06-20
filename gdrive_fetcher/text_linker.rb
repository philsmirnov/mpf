# encoding: UTF-8

module GDriveImporter

  class TextLinker

    MAIN_REGEX = /(?<=\()\s?с[рм]\.?[^\)]*?(?=\))/im

    def initialize(text_collection, main_regexp, regexps)
      @collection = text_collection
      @main_regexp = main_regexp
      @regexps = regexps
    end

    def regexp_helper(s)
      s.gsub(/[:\-,\.]/, ' ').gsub(/^\d\d/, '').gsub(/[[:space:]][[:space:]]/, ' ').gsub(/(?<=[^0-9\s])(\d)/, ' \\1')
    end

    def find_item_in_collection(regexp, title, is_folder)
      iterator = is_folder ? @collection : @collection.files
      item = iterator.find do |f|
        if f =~ regexp
          puts "found #{f.class}: #{f.number} #{f.title}"
          true
        else
          false
        end
      end
      return {:title => title, :fof => item} if item
      nil
    end

    def create_regex_and_find_item(k, is_folder)
      link_title = k.first.strip
      regexp = Regexp.new(Regexp.escape(regexp_helper link_title), 'i')
      find_item_in_collection(regexp, link_title, is_folder)
    end

    def process_links(file)
      file.contents.gsub!(@main_regexp) do |raw_link_text|
        puts raw_link_text

        is_folder = raw_link_text =~ /с[мр]\.?[[:space:]]*(п(\.|\s)|пап)/i

        items = []

        @regexps.each do |regexp|
          break unless items.empty?
          raw_link_text.scan(regexp) do |link|
            item = create_regex_and_find_item(link, is_folder)
            items << item if item
          end
        end
        yield(items)
      end
    end
  end

end