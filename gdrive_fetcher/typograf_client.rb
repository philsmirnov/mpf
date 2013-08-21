class TypografClient

  def initialize(typograph_settings)
    @typograph_settings = typograph_settings
  end

  def typografy(text)
    text
    #RestClient.post('http://typograf.ru/webservice/', :text => text, :chr => 'UTF-8', :xml => @typograph_settings).
    #gsub(/&lt;%/, '<%').
    #gsub(/%&gt;/, '%>')
  end
end