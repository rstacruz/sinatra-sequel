require 'time'
require 'sinatra/base'
require 'sequel'

module Sinatra
  module SequelHelper
    def database
      options.database
    end
  end

  module SequelExtension
    def database=(url)
      @database = nil
      set :database_url, url
      database
    end

    def database
      # MySQL's UTF-8 encoding is "utf8" without the hyphen.
      is_mysql = database_url =~ /^mysql/
      encoding = is_mysql ? "utf8" : "utf-8"

      @database ||=
        Sequel.connect(database_url, :encoding => encoding)
    end

    def migration(name, &block)
      create_migrations_table
      return if database[migrations_table_name].filter(:name => name).count > 0
      migrations_log.puts "Running migration: #{name}"
      database.transaction do
        yield database
        database[migrations_table_name] << { :name => name, :ran_at => Time.now }
      end
    end

    Sequel::Database::ADAPTERS.each do |adapter|
      define_method("#{adapter}?") { @database.database_type == adapter }
    end

  protected

    def mysql?
      defined?(Sequel::MySQL::Database) && database.kind_of?(Sequel::MySQL::Database)
    end

    def create_migrations_table
      is_mysql = mysql?

      database.create_table? :migrations do
        primary_key :id

        if is_mysql
          # MySQL indices need a size, which Sequel doesn't seem to support.
          String :name, :null => false
        else
          String :name, :null => false, :index => true
        end
        timestamp :ran_at
      end
    end

    def self.registered(app)
      app.set :database_url, lambda { ENV['DATABASE_URL'] || "sqlite://#{environment}.db" }
      app.set :migrations_table_name, :migrations
      app.set :migrations_log, lambda { STDOUT }
      app.helpers SequelHelper
    end
  end

  register SequelExtension
end
