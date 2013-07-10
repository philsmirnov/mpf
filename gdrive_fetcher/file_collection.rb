# encoding: UTF-8

require_relative 'folder'

module GDriveImporter
  class FileCollection
    include Enumerable

    def initialize(collection, coder)
      @folders = []
      @coder = coder
      collection.subcollections.
        sort_by {|f| f.title}.
        each{|folder| import_folder folder}
    end

    def import_folder(folder)
      folder = GDriveImporter::Folder.new(folder, @coder)
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

    def save(path)
      @folders.each{|f| f.save path }
    end

  end
end
