
module FileUtils
  def make_title_for_search(s)
    result = s.gsub(/[\(:\-,\.\)]/, ' ').gsub(/^\d\d/, '').gsub(/[[:space:]]{1,3}/, ' ')
    ::Unicode::normalize_C result
  end

  def make_title_for_save(s)
    s.gsub(/^\d\d/, '').parameterize
  end

  def =~(regexp)
    @title_for_search =~ regexp
  end

end