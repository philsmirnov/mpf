# encoding: UTF-8

module GDriveImporter

  class TextLinker

    attr_accessor :regexp_lambda

    MAIN_REGEX = /(?<=\()\s?с[рм]\.?[^\)]*?(?=\))/im

    def initialize(text_collections, main_regexp, regexps)
      @collections = text_collections
      @main_regexp = main_regexp
      @regexps = regexps
      @regexp_lambda = Proc.new if block_given?
    end

    def regexp_helper(s)
      s = Unicode::normalize_C(coder.decode(s))
      s.gsub(/[:\-,\.]/, ' ').gsub(/^\d\d/, '').gsub(/[[:space:]][[:space:]]/, ' ').gsub(/(?<=[^0-9\s])(\d)/, ' \\1')
    end

    def find_item_in_collection(regexp, title, is_folder)
      @collections.each do |collection|
        iterator = is_folder ? collection : collection.files
        items = iterator.select do |f|
          if f =~ regexp
            puts "found #{f.class}: #{f.number} #{f.title}"
            true
          else
            false
          end
        end
        item = items.min_by{|i| i.title.length}
        return {:title => title, :fof => item} if item
      end
      nil
    end

    def create_regex_and_find_item(k, is_folder)
      link_title = (k.is_a?(Array) ? k.first : k).strip
      link_title = regexp_helper link_title
      if @regexp_lambda
        regexp = @regexp_lambda.call(link_title)
      else
        regexp = Regexp.new(Regexp.escape(link_title), 'i')
      end

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
        yield(items, raw_link_text)
      end
    end
  end

end