# encoding: UTF-8

require 'test/unit'
require 'htmlentities'
require '../../text_linker'
require '../../article_linker'


class ArticleLinkerTest < Test::Unit::TestCase

  def test_article_linker

    f = Struct.new(:title, :number, :parent_folder, :title_for_save) do
      def =~(regexp)
        title =~ regexp
      end
    end

    col = Struct.new(:files, :title, :title_for_save)
    c = col.new [f.new("you", 555, nil, "title_for_save")], 'col', 'col_title_for_save'


    c.files.first.parent_folder = c


    sp = GDriveImporter::ArticleLinker.new [c]
    res = "принадлежит <em class=\"underline\">you</em>, кроме обычных людей есть еще люди талантливые"
    sp.process_links res
    expected = "принадлежит <%= link_to('<em class=\"underline\">you</em>',  '/personalii/title_for_save .html') %>, кроме обычных людей есть еще люди талантливые"
    assert res == expected , lambda {"expected #{expected}, but got #{res}"}
  end
end
