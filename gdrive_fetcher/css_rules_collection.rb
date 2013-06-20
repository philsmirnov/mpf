class CssRulesCollection
  attr_accessor :tag
  attr_accessor :selectors

  def initialize(tag, css_rules)
    @tag = tag
    @selectors = css_rules.map{|css_rule| css_rule.selectors.first}
    @css_rules = css_rules
  end


end