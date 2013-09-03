# encoding: UTF-8

require 'test/unit'
require '../../file'

class MyFileTest < Test::Unit::TestCase

  def test_to_pager
    f_klass = Struct.new(:title, :title_for_save)
    f1_folder = f_klass.new('folder_title1', 'folder_title_for_save1')
    f1_file = f_klass.new('title1', 'title_for_save1')
    f1 = GDriveImporter::File.new f1_folder, f1_file, Object.new

    expected = {:title =>'title1' , :link => '/texts/folder_title_for_save1/title1.html' }
    actual = f1.to_pager('texts')
    assert  actual == expected, lambda {"expected #{expected}, but got #{actual}"}

  end

end