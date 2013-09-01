# encoding: UTF-8

require 'htmlentities'
require 'pathname'
require 'unicode'
require 'roman-numerals'

require_relative 'file_utils'
require_relative 'file'

module GDriveImporter

  class Folder

    include Enumerable
    include FileUtils

    attr_reader :files, :title, :title_for_search, :title_for_save, :number

    def initialize(gdrive_folder, coder)
      @gdrive_folder = gdrive_folder
      @coder = coder
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

    def link_to(target_file, title = nil)
      title ||= @title
      folder = target_file.parent_folder  == self ? '' : "../#{@title_for_save}/"
      "<a href='#{folder}index.html'>#{title}</a>"
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

    def next_three(target)
      files_to_skip = find_index{|f| f == target} + 1
      return nil if files_to_skip >= @files.count

      drop(files_to_skip).take(3).map do |file|
        {
            :title => file.title,
            :link  => "#{file.title_for_save}.html",
            :number => file.number,
            :first_paragraph => file.first_paragraph
        }
      end
    end

    def pager(target)
      files = self.to_a
      i = find_index{|f| f == target}
      prev_file = i == 0 ? files.last : files[i-1]
      next_file = i == files.count-1 ? files.first : files[i+1]
      {
          :prev => prev_file.to_pager,
          :next => next_file.to_pager
      }
    end
  end
end
