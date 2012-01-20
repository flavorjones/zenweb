require "rubygems"
gem "rake"
require "rake"

require "zenweb/page"
require "zenweb/config"
require "zenweb/extensions"

module Zenweb
  class Site
    include Rake::DSL

    attr_reader :pages, :configs

    def self.load_plugins
      Gem.find_files("zenweb/plugins/*.rb").each do |path|
        require path
      end
    end

    self.load_plugins

    def initialize
      @layouts = {}
      @pages = {}
      @configs = Hash.new { |h,k| h[k] = Config.new self, k }
    end

    def categories
      @categories ||=
        begin
          h = Hash.new { |h,k| h[k] = [] }

          def h.method_missing msg, *args
            if self.has_key? msg.to_s then
              self[msg.to_s]
            else
              super
            end
          end

          pages.each do |url, page|
            dir = url.split(/\//).first
            next unless File.directory? dir and dir !~ /^_/
            next if url =~ /index.html/ or url !~ /html/
            h[dir] << page
          end

          h.keys.each do |dir|
            h[dir] = h[dir].sort_by { |p| [-p.date.to_i, p.title ] }
          end

          h
        end
    end

    def config
      configs["_config.yml"]
    end

    def generate
      task(:site).invoke
    end

    def html_pages
      self.pages.values.select { |p| p.url_path =~ /\.html/ }
    end

    def inspect
      "Site[#{pages.size} pages, #{configs.size} configs]"
    end

    def layout name
      @layouts[name]
    end

    def method_missing msg, *args
      config[msg.to_s] || warn("#{self.inspect} does not define #{msg}")
    end

    def pages_by_date
      pages.values.select {|page| page["title"] && page.date }.
        sort_by { |page| [-page.date.to_i, page.title] }
    end

    def scan
      excludes = Array(config["exclude"])

      top = Dir["*"] - excludes
      files, dirs = top.partition { |path| File.file? path }
      files += Dir["{#{top.join(",")}}/**/*"].reject { |f| not File.file? f }

      renderers_re = Page.renderers_re

      files.each do |path|
        case path
        when /(?:~|#{excludes.join '|'})$/
          # ignore
        when /^_layout/ then
          ext = File.extname path
          name = File.basename path, ext
          @layouts[name] = Page.new self, path
        when /^_/ then
          next
        when /\.yml$/ then
          @configs[path] = Config.new self, path
        when /\.(?:txt|html|css|js|png|jpg|gif|eot|svg|ttf|woff|ico)$/, renderers_re then # HACK
          @pages[path] = Page.new self, path
        else
          warn "unknown file type: #{path}" if Rake.application.options.trace
        end
      end
    end

    def wire
      directory ".site"
      task :site => ".site"

      configs.each do |path, config|
        config.wire
      end

      pages.each do |path, page|
        page.wire
      end

      $website = self # HACK
      task(:extra_wirings).invoke
    end
  end # class Site
end
