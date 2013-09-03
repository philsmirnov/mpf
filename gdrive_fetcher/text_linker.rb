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
      found_items = []
      @collections.each do |collection|
        iterator = is_folder ? collection : collection.files
        found_items << iterator.select { |f| f =~ regexp}
      end
      item = found_items.flatten.min_by{|i| i.title.length}
      item ? {:title => title, :fof => item} : nil
    end

    def preprocess_link_title(k)
      regexp_helper(k.is_a?(Array) ? k.first : k)
    end

    def create_regex_and_find_item(link_title, is_folder)
      regex_source = preprocess_link_title(link_title)
      if @regexp_lambda
        regexp = @regexp_lambda.call(regex_source)
      else
        regexp = Regexp.new(Regexp.escape(regex_source), 'i')
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
            modified_link = preprocess_link_title(link)
            next if modified_link == ''
            link = link.is_a?(Array) ? link.first : link
            item, used_regexp = create_regex_and_find_item(link, is_folder)
            if item
              items << item
              not_found.delete(modified_link)
            else
              not_found[modified_link] = "Link not found: #{modified_link} \n\tRaw text: #{raw_link_text} \n\tSearched: #{link}\n\t" +
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