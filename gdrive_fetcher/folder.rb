# encoding: UTF-8

require 'htmlentities'
require 'pathname'
require 'unicode'
require 'roman-numerals'

require_relative 'file_utils'
require_relative 'folder_utils'
require_relative 'file'


module GDriveImporter

  class Folder

    include Enumerable
    include FileUtils
    include FolderUtils

    attr_reader :files, :title, :title_for_search, :title_for_save, :number, :parent_folder

    def initialize(gdrive_folder, coder, parent_folder = nil)
      @gdrive_folder = gdrive_folder
      @coder = coder
      @parent_folder = parent_folder
      @files = []

      @title = gdrive_folder.title
      @number = @title[/^\d\d/].to_i
      @title = @title.gsub(/^\d\d/, '').gsub(/\+*/, '').strip

      @title_for_search = make_title_for_search(@title)
      @title_for_save = make_title_for_save(@title)
    end

    def import
      @gdrive_folder.files.sort_by {|f| f.title}.each do |gdrive_file|
        content_types = gdrive_file.available_content_types()
        (puts "file #{gdrive_file.title} has improper type" && next) if content_types.none?{ |ct| ct == 'text/html'}
        file = GDriveImporter::File.new self, gdrive_file, @coder
        @files << file unless @files.include? file
      end
    end

    def each
      @files.each do |file|
        next if file =~ /intro/i
        yield file
      end
    end

    def save(path)
      each {|f| f.save(f.generate_path(path))}
    end

    def generate_path(path)
      Pathname.new(path) + @title_for_save
    end

    def link_to(title = nil)
      title ||= @title
      "<%= link_to('#{title}', '/home.html', :fragment => '#{self.title_for_save}') %>"
    end

    def content_table
      result = <<-eos
---
title: "#{title}"
---

<%= partial 'there_is_exit' %>

<div class="row">
  <%= partial 'sidebar_contents'%>

  <div class="large-8 columns">
    <img src='../img/chapters/#{@number}.png'>
    <h3 class="app_thin app_lgray">Глава #{@number}. #{title}</h3>
      eos

      each do |file|
        link = "/texts/#{@title_for_save}/#{file.title_for_save}.html"
        result << <<-eos
        <h4 class="app_chapter">
          <%= link_to '#{file.title}', '#{link}' %>
        </h4>
        <p>
          <%= link_to truncate('#{file.first_paragraph}', :length => 150), '#{link}', :class => "app_black" %>
        </p>
        eos
      end
      result << '</div>'
      result << '</div>'
    end

    def parent_folder_title
      @parent_folder.title_for_save =~ /glos/ ? 'glossariy' : 'personalii'
    end

    def pager(target)
      return @parent_folder.pager(target, 'texts') if @parent_folder
      super(target, to_enum(:each))
    end

    def next_three(target)
      @parent_folder.next_three(target, 'texts') if @parent_folder
    end
  end
end
