# encoding: UTF-8

require_relative 'folder'
require_relative 'folder_utils'

module GDriveImporter

  class FileCollection
    include Enumerable
    include FolderUtils

    attr_reader :title

    def initialize(collection, coder)
      @folders = []
      @coder = coder
      @title = collection.title
      collection.subcollections.
        sort_by {|f| f.title}.
        each{|folder| import_folder folder}
    end

    def import_folder(folder)
      folder = GDriveImporter::Folder.new(folder, @coder, self)
      folder.import
      @folders << folder unless @folders.include? folder
    end

    def each
      @folders.each do |folder|
        yield folder
      end
    end

    def each_file
      @folders.each do |folder|
        folder.each do |file|
          yield file
        end
      end
    end

    def files
      enum_for(:each_file)
    end

    def pager(target, path)
      super(target, Enumerator.new(self, :each_file), path)
    end

    def next_three(target, path)
      super(target, Enumerator.new(self, :each_file), path)
    end

    def save(path)
      @folders.each{|f| f.save path }
    end

  end
end
