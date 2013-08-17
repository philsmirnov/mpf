# encoding: UTF-8
require 'css_parser'
require_relative 'css_rules_collection'

module GDriveImporter

  class TextConverter

    def convert(file)
      @parser = CssParser::Parser.new
      @file   = file
      bad_rules = []

      doc = Nokogiri::HTML(file.original_contents)

      found_rules = find_rules(doc)
      @parser.each_rule_set do |rs|
        bad_rules << rs if found_rules.none? {|gr| gr.selectors.include? rs.selectors.first}
      end

      title = doc.at_css('p').text
      file.metadata['title'] = title
      doc.at_css('p').remove

      strip_all_unused_rules(doc, bad_rules, found_rules)
      remove_empty_tags(doc)
      change_tags_to_em(doc, found_rules)

      fragment = Nokogiri::HTML.fragment(doc.at_css('body').inner_html)
      file.contents = fragment.to_html
      #file.contents = @typograf.typograf(fragment.to_html)
      #file.contents = file.contents.gsub(/(?<=[[:space:]\(])["]/, '«')
      #.gsub(/["](?=[\s\.!\?,:;\)\][[:space:]]])(?![>])/, '»')
      #.gsub(/“/, '«')
      #.gsub(/”/, '»')
      file.first_paragraph = fragment.at_css('p').text unless file.first_paragraph
      fragment
    end


    def find_rules(doc)

      css_block = (doc.xpath '//style/text()').first.to_str

      rename_rules = {
          :em => /font-style: italic/,
          :bold => /font-weight: bold/,
          :underline => /text-decoration: underline/,
          :epigraph => /text-align:right/
      }

      good_rules = []

      @parser.add_block!(css_block)

      rename_rules.each { |rename_rule|
        tmp_rules = []
        @parser.each_rule_set do |rule_set|
          next if rule_set.selectors.none? { |s| s =~ /\.c\d/ }
          if rule_set.declarations_to_s =~ rename_rules[rename_rule.first]
            tmp_rules << rule_set
          end
        end
        good_rules << CssRulesCollection.new(rename_rule.first, tmp_rules)
      }
      good_rules
    end

    def strip_all_unused_rules(doc, bad_rules, good_rules)
      begin
        number_of_replacements = 0
        bad_rules.each do |bad_rule|
          doc.css(bad_rule.selectors.first).each do |node|
            node_class = node[:class]
            next if node.name == 'body'
            next if !node_class
            if node_class.split(' ').none?{|css_class| good_rules.any? {|css_rules| css_rules.selectors.include? ".#{css_class}" } }
              if node.name == 'p'
                node.remove_attribute 'class'
              else
                node.replace node.inner_html
              end
              number_of_replacements += 1
            end
          end
        end
      end while number_of_replacements > 0
    end

# every class goes to its tag, combinations are left for now
    def change_tags_to_em(doc, good_rules)
      bold_rule = good_rules.find{|r|  r.tag == :bold}
      em_rule = good_rules.find{|r|  r.tag == :em}
      underline_rule = good_rules.find{|r|  r.tag == :underline}

      good_rules.each do |rule|

        doc.css(*rule.selectors).each do |node|
          node_class = node[:class]
          next if node.name == 'body'
          next if !node_class
          node_classes = node_class.split(' ').map {|css_class| ".#{css_class}"}
          difference = node_classes - rule.selectors
          if difference.empty? || # none of the classes are different - 1:1 case
              good_rules.none?{|good_rule| difference.any?{|d| good_rule.selectors.include?(d)} }
            if rule.tag == :em
              node.replace doc.create_element('em', node.inner_html)
            end
            if rule.tag == :bold
              node.replace doc.create_element('em', node.inner_html, :class => 'strong')
            end
            if rule.tag == :underline
              node.replace doc.create_element('em', node.inner_html, :class => 'underline')
            end
            if rule.tag == :epigraph
              node.replace doc.create_element('p', node.inner_html, :class => 'app_epigraph')
            end

          else # we have something, this must be a n:2 case
               #is it em class strong?
            if (difference - (bold_rule.selectors + em_rule.selectors)).empty?
              node.replace doc.create_element('em', node.inner_html, :class => 'strong')
              next
            end

            if (difference - (underline_rule.selectors + em_rule.selectors)).empty?
              node.replace doc.create_element('em', node.inner_html, :class => 'underline')
            end
          end
        end
      end
    end

    def remove_empty_tags(doc)
      doc.css('span').each do |node|
        node.replace(node.inner_html) if !node[:class]
      end
      2.times do
        doc.css('span', 'p', 'em').each do |node|
        node.replace(' ') if node.inner_html.strip == ''
        end
      end
    end
  end
end
