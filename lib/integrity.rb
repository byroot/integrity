$:.unshift File.expand_path(File.dirname(__FILE__))

require "json"
require "haml"
require "dm-core"
require "dm-validations"
require "dm-types"
require "dm-timestamps"
require "dm-aggregates"
require "sinatra/base"

require "yaml"
require "logger"
require "digest/sha1"
require "timeout"
require "ostruct"
require "pathname"

require "integrity/core_ext/object"

require "integrity/project"
require "integrity/author"
require "integrity/commit"
require "integrity/build"
require "integrity/project_builder"
require "integrity/scm"
require "integrity/scm/git"
require "integrity/notifier"
require "integrity/helpers"
require "integrity/app"

module Integrity
  def self.new(config=nil)
    if config.is_a?(String) && File.file?(config)
      self.config = YAML.load_file(config)
    elsif config.is_a?(Hash)
      self.config = config
    end

    DataMapper.setup(:default, self.config[:database_uri])
  end

  def self.register_notifier(klass)
    raise ArgumentError unless valid_notifier?(klass)

    self.notifiers[klass.to_s.split(":").last] = klass
  end

  def self.notifiers
    @notifiers ||= {}
    @notifiers
  end

  def self.default_configuration
    @defaults ||= { :database_uri      => "sqlite3::memory:",
                    :export_directory  => "/tmp/exports",
                    :log               => STDOUT,
                    :base_uri          => "http://localhost:8910",
                    :use_basic_auth    => false,
                    :build_all_commits => true,
                    :log_debug_info    => false }
  end

  def self.config
    @config ||= default_configuration.dup
  end

  def self.config=(options)
    @config = default_configuration.merge(options)
  end

  def self.log(message, &block)
    logger.info(message, &block)
  end

  def self.logger
    @logger ||= Logger.new(config[:log], "daily").tap do |logger|
      logger.formatter = LogFormatter.new
    end
  end
  private_class_method :logger

  def self.valid_notifier?(notifier)
    notifier.respond_to?(:to_haml) && notifier.respond_to?(:notify_of_build) &&
      notifier != Notifier::Base
  end
  private_class_method :valid_notifier?

    class LogFormatter < Logger::Formatter
      def call(severity, time, progname, msg)
        time.strftime("[%H:%M:%S] ") + msg2str(msg) + "\n"
      end
    end
end
