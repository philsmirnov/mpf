module FolderUtils

  def pager(target, iterator, path = nil)
    prev_file = nil
    next_file = nil
    should_break = false

    iterator.each do |file|
      if should_break
        next_file = file
        break
      end
      should_break = file == target
      prev_file = file unless should_break
    end

    {
        :prev => prev_file ? prev_file.to_pager : nil,
        :next => next_file ? next_file.to_pager : nil
    }
  end

  def next_three(target, iterator, path = nil)
    files_to_skip = iterator.find_index{|f| f == target} + 1
    return nil if files_to_skip >= iterator.count

    iterator.drop(files_to_skip).take(3).map do |file|
      {
          :title => file.title,
          :link  => file.absolute_path,
          :number => file.number,
          :first_paragraph => file.first_paragraph
      }
    end
  end
end