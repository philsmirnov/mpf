# encoding: UTF-8
require 'rack/offline'
require 'active_support/core_ext/string/inflections'
require 'russian'

I18n.locale = :'ru'
I18n.reload!

###
# Compass
###

# Susy grids in Compass
# First: gem install susy
# require 'susy'

# Change Compass configuration
# compass_config do |config|
#   config.output_style = :compact
# end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end


with_layout :text do
    page '/texts/*'
end


with_layout :layout do
  page '/texts/*/index.*'
end


with_layout :topic do
    page '/topics/*'
    page '/glossariy/*'
end

with_layout :persona do
  page '/personalii/*'
end

set :relative_links, true

set :offline, false


# Proxy (fake) files
# page "/this-page-has-no-template.html", :proxy => "/template-file.html" do
#   @which_fake_page = "Rendering a fake page with a variable"
# end

###
# Helpers
###

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes

# Methods defined in the helpers block are available in templates
helpers do
  def current_page_title
    (current_page.data.title? && current_page.data.title)  || 'PAPPUSH'
  end

  def current_page_first_paragraph
    (current_page.data.first_paragraph? && current_page.data.first_paragraph)  || 'философ'
  end

  def active_class(regexps)
    ' active' if regexps.any?{|r| current_page.path =~ r}
  end

  def double_dots
    '../' * (current_page.url.count('/') - 1)
  end

  def current_chapter
    #(current_page.data.chapter_title? && current_page.data.chapter_title)  || 'Глава 1. Лабиринт'
    data.home.chapters.each do |c|
      return c if c[:files].find {|f| f[:title_for_save] =~ Regexp.new(current_page.path.split('/').last)}
    end
    return nil
  end

  def pager(direction)
    pager_data = current_page.data.pager
    if pager_data && pager_data[direction]
      link_to pager_data[direction][:title],  pager_data[direction][:link]
    else
      "#"
    end
  end

  def picture(img_name)
    content_tag :div, :class => 'text_img' do
      image_tag("../../img/texts/#{img_name}.png")
    end
  end

end

set :css_dir, 'css'
set :js_dir, 'js'
set :images_dir, 'img'
set :partials_dir, 'partials'


# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  # activate :minify_css

  # Minify Javascript on build
  # activate :minify_javascript

  # Enable cache buster
  # activate :cache_buster
  
  activate :asset_hash, :exts => %w(.jpg .jpeg .png .gif .js .css .otf .woff .eot .ttf .svg), :ignore => [/startup/, /apple-touch-icon/]

  # Use relative URLs
  activate :relative_assets

  # Compress PNGs after build
  # First: gem install middleman-smusher
  # require "middleman-smusher"
  # activate :smusher

  # Or use a different image path
  #set :http_path, "/mp"
end


offline = Rack::Offline.configure {}
map('/offline.appcache') { run offline }
endpoint 'offline.appcache'

ALLOWED_EXTS = %w(css eot gif html jpg png svg ttf txt woff xml js)

ready do
  all_pages = sitemap.resources.map{|r| r.destination_path }
	offline = Rack::Offline.configure do
		all_pages.each do|page|
      cache page if ALLOWED_EXTS.any? {|ext| ext == page[/(\w+)$/]}
    end
    network "*"
	end
end
