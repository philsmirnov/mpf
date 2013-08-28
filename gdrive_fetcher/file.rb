# encoding: UTF-8

require 'yaml'
require 'pathname'
require 'unicode'
require 'forwardable'
require 'date'
require_relative 'file_utils'


module GDriveImporter

  class File

    include FileUtils
    extend Forwardable

    attr_accessor :contents, :original_contents, :title, :metadata, :show_next_three, :first_paragraph
    attr_reader :parent_folder, :title_for_save, :number

    def_delegators :@gdrive_file, :resource_id, :resource_type, :document_feed_url, :human_url, :document_feed_entry

    def initialize(folder, file, coder)
      @gdrive_file = file
      @coder = coder

      @title = file.title
      @number = @title[/^\d\d/].to_i
      @title = @title.gsub(/^\d\d/, '').gsub(/\+*/, '').strip

      @parent_folder = folder
      @metadata = {}
      @metadata['title'] = @title
      @metadata['chapter_title'] = folder.title if folder

      @title_for_search = make_title_for_search(@title)
      @title_for_save = make_title_for_save(@title)
      @show_next_three = true
    end

    def fetch
      @original_contents = @gdrive_file.download_to_string(:content_type => 'text/html')
      @original_contents = ::Unicode::normalize_C(@coder.decode(@original_contents))
    end

    def has_no_linked_articles
      @metadata[:linked_articles] == nil || @metadata[:linked_articles].length == 0
    end

    def to_linked_article(original_title)
      {
          :original_title => original_title,
          :file_title => @title,
          :file_name => @title_for_save,
          :parent_folder => @parent_folder.title_for_save,
          :is_folder => false
      }
    end

    def set_linked_articles(found_articles)
      @metadata[:linked_articles] = found_articles.
          uniq.
          select { |item| ['glossariy', 'personalii'].include? item[:fof].parent_folder.title_for_save }.
          map { |item| item[:fof].to_linked_article(item[:title])}
    end

    def fetch_text
      sio = StringIO.new()
      url = @gdrive_file.document_feed_entry.css("content").first["src"] + "&format=txt"
      session = @gdrive_file.instance_variable_get :@session

      body = session.request(:get, url, :response_type => :raw, :auth => :writely)
      #body = RestClient.post('http://typograf.ru/webservice/', :text => body, :chr => 'UTF-8')
      sleep 1

      sio.write(body)
      sio.string.gsub!(/^\xEF\xBB\xBF/, '')
    end

    def generate_metadata
      if @show_next_three
        read_later = @parent_folder.next_three(self)
        @metadata['read_later'] = read_later if read_later
      end
      @metadata['pager'] = @parent_folder.pager(self)
      @metadata
    end

    def first_paragraph
      @metadata['first_paragraph']
    end

    def first_paragraph=(paragraph)
      @metadata['first_paragraph'] = paragraph
    end

    def updated_at
      Time.parse(@gdrive_file.document_feed_entry.css('updated').text)
    end

    def generate_path(path)
      path_name = @parent_folder.generate_path(path)
      raise 'No contents to save' unless @contents || @original_contents
      @original_contents ?
          path_name + "my_#{@title_for_save}.html" :
          path_name + "google_#{@title_for_save}.html"
    end

    def save(path = nil)
      raise 'No content to save' unless @contents
      path ||= generate_filename
      f = ::File.new(path, 'w+')
      generate_metadata
      f.write(@metadata.to_yaml << '---' << "\n\n")
      f.write(@contents)
      f.close
    end

    def generate_filename
      raise 'No contents to save' unless @contents || @original_contents
      return "#{@title_for_save}.html.erb" if @contents
      "google_#{@title_for_save}.html"
    end

    def save_original(path = nil)
      raise 'No content to save' unless @original_contents
      path ||= generate_filename
      f = ::File.new(path, 'w+')
      f.write(@original_contents)
      f.close
    end

    def link_to(target_file, title = nil, path = nil)
      title ||= @title
      folder = target_file.parent_folder == @parent_folder ? '' : "../#{@parent_folder.title_for_save}/"
      folder = "../#{path}/#{@parent_folder.title_for_save}/" if path
      "<a href='#{folder}#{@title_for_save}.html'>#{title}</a>"
    end

    def link_to2(target_file, title = nil, path = nil)
      title ||= @title
      folder = target_file.parent_folder == @parent_folder ? '' : "../#{@parent_folder.title_for_save}/"
      folder = "../#{path}/#{@parent_folder.title_for_save}/" if path
      "<%= link_to('#{title}', '/#{@title_for_save}.html') %>"
    end
  end
end
