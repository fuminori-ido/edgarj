require 'core_ext/active_record'
require 'core_ext/resources'
require 'edgarj/enum_cache'

module Edgarj
  class Engine < ::Rails::Engine
    config.app_generators do |g|
      g.templates.unshift File::expand_path('../templates', __FILE__)
    end

    # Require/load application side edgarj config in RAILS_ROOT/config/edgarj/
    def self.load_edgarj_conf_in_app
      [
        Dir.glob(File.join(Rails.root, "config/edgarj/**/*.rb"))
      ].flatten.each do |edgarj_conf|
        Rails.application.config.cache_classes ?
            require(edgarj_conf) :
            load(edgarj_conf)
      end
    end

    # Require/load (based on config) all decorators from app/decorators/
    #
    # thanks:
    # * http://edgeguides.rubyonrails.org/engines.html#overriding-models-and-controllers
    # * https://github.com/resolve/refinerycms/commit/3387b547f8e58c9fced9eee78ca1bd2acd2588c2
    def self.load_decorators
      [
        Dir.glob(File.join(Rails.root, "app/decorators/**/*_decorator.rb"))
      ].flatten.each do |decorator|
        Rails.application.config.cache_classes ?
            require(decorator) :
            load(decorator)
      end
    end

    # make edgarj related work directories
    def self.make_work_dir
      work_dirs = [
        Rails.root + 'tmp/edgarj',
        Rails.root + 'tmp/edgarj/csv_download'
      ]
      for dir in work_dirs do
        FileUtils.mkdir_p(dir) if !File.directory?(dir)
      end
    end

    initializer "edgarj" do
      ActiveRecord::SessionStore::Session.table_name = 'edgarj_sssns'
      Engine::load_edgarj_conf_in_app
      Engine::load_decorators
      for file in Dir.glob(File.join(File.dirname(__FILE__), "../../locale/*.yml")) do
        I18n.load_path << file
      end
      Engine::make_work_dir
    end
  end
end
