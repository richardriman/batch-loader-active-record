require 'active_record'
require 'active_support/notifications'
require 'securerandom'

# Establish database connection
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new(File.expand_path("../../log/active_record.log", __dir__))

module ActiveRecordHelpers
  def new_model(create_table, fields = {}, &block)
    table_name = "#{create_table}_#{SecureRandom.hex(6)}"
    model = Class.new(ActiveRecord::Base) do
      self.table_name = table_name
      connection.create_table(table_name, :force => true) do |table|
        fields.each { |name, type| table.public_send(type, name) }
      end

      singleton_class.class_eval do
        define_method(:name) { "#{create_table.to_s.capitalize}" }
      end
    end
    model.class_eval(&block) if block_given?
    model.reset_column_information
    model
  end

  attr_reader :monitored_queries

  def start_query_monitor
    @monitored_queries = []
    @subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      @monitored_queries << payload[:sql]
    end
  end

  def stop_query_monitor
    return unless @subscriber
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    @subscriber = nil
  end
end

RSpec.configure do |config|
  config.include ActiveRecordHelpers
end