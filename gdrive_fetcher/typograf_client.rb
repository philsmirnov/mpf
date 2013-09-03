class TypografClient

  def initialize(skip_typograph, typograph_settings)
    @skip = skip_typograph
    @typograph_settings = typograph_settings
  end

  def typografy(text)
    return text if @skip
    RestClient.post('http://typograf.ru/webservice/', :text => text, :chr => 'UTF-8', :xml => @typograph_settings).
    gsub(/&lt;%/, '<%').
    gsub(/=&gt;/, '=>').
    gsub(/%&gt;/, '%>')
  end
end