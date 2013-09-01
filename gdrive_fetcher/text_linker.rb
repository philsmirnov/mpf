# encoding: UTF-8

require 'active_support/core_ext/string/filters'

module GDriveImporter

  class TextLinker

    attr_accessor :regexp_lambda

    MAIN_REGEX = /(?<=\()\s?с[рм]\.?[^\)]*?(?=\))/im

    def initialize(text_collections, main_regexp, regexps)
      @collections = text_collections
      @main_regexp = main_regexp
      @regexps = regexps
      @regexp_lambda = Proc.new if block_given?
      @coder = HTMLEntities.new
    end

    def regexp_helper(s)
      s.gsub(/[[:space:]]{1,4}/, ' ').strip.
          gsub(/[\(:\-,\.\)]/, ' ').
          gsub(/^\d\d/, '').
          gsub(/(?<=[^0-9\s])(\d)/, ' \\1').
          squish
    end

    def find_item_in_collection(regexp, title, is_folder)
      @collections.each do |collection|
        iterator = is_folder ? collection : collection.files
        item = iterator.select { |f| f =~ regexp}.min_by{|i| i.title.length}
        return {:title => title, :fof => item} if item
      end
      nil
    end

    def preprocess_link_title(k)
      regexp_helper(k.is_a?(Array) ? k.first : k)
    end

    def create_regex_and_find_item(link_title, is_folder)
      if @regexp_lambda
        regexp = @regexp_lambda.call(link_title)
      else
        regexp = Regexp.new(Regexp.escape(link_title), 'i')
      end
      [find_item_in_collection(regexp, link_title, is_folder), regexp]
    end

    def process_links(text)
      text.gsub!(@main_regexp) do |raw_link_text|
        is_folder = raw_link_text =~ /с[мр]\.?[[:space:]]*(п(\.|\s)|пап)/i
        items = []
        not_found = {}

        @regexps.each do |regexp|
          break unless items.empty?
          raw_link_text.scan(regexp) do |link|
            link_title = preprocess_link_title(link)
            next if link_title == ''
            item, used_regexp = create_regex_and_find_item(link_title, is_folder)
            if item
              items << item
              not_found.delete(link_title)
            else
              not_found[link_title] = "Link not found: #{link_title} \n\tRaw text: #{raw_link_text} \n\tSearched: #{link}\n\t" +
                  'Collections: ' + @collections.map{|c| c.title.gsub(/[\.]/, ' ').squish}.join(', ') +
                  "\n\tIs folder: #{!!is_folder}" +
                  "\n\tRegexp: #{used_regexp}"
            end
          end
        end

        not_found.each {|k,v| puts v}
        yield(items, raw_link_text)
      end
    end
  end

end