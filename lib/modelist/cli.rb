require 'thor'

module Modelist
  class CLI < Thor
    desc "test", "Tests specified models, their attributes, and their associations. Will test all models if no models are specified."
    method_option :output_file, :desc => "Pathname of file to output to"
    def test(*args)
      # load Rails environment
      require './config/environment'
      require 'modelist/tester'
      #args = options[:models] ? options.delete(:models).split(',').collect{|s|s.strip} << options : []
      puts "args=#{args.inspect}"
      args.each {|a| puts "Unsupported option: #{args.delete(a)}" if a.to_s.starts_with?('-')}
      exit ::Modelist::Tester.test_models(*args) ? 0 : 1
    end

    desc "required", "Finds model dependencies in specified models."
    def required(*args)
      # load Rails environment
      require './config/environment'
      require 'modelist/analyst'
      # args are [*options[:models], options hash (minus the models)]
      #args = options[:models] ? options.delete(:models).split(',').collect{|s|s.strip} << options : []
      puts "args=#{args.inspect}"
      args.each {|a| puts "Unsupported option: #{args.delete(a)}" if a.to_s.starts_with?('-')}
      Modelist::Analyst.find_required_models(*args)
      exit 0
    end

    desc "circular", "Checks for required circular references in specified models. Will test all models if no models are specified."
    method_option :output_file, :desc => "Pathname of file to output to"
    def circular(*args)
      # load Rails environment
      require './config/environment'
      require 'modelist/circular_ref_checker'
      #args = options[:models] ? options.delete(:models).split(',').collect{|s|s.strip} << options : []
      puts "args=#{args.inspect}"
      args.each {|a| puts "Unsupported option: #{args.delete(a)}" if a.to_s.starts_with?('-')}
      exit ::Modelist::CircularRefChecker.test_models(*args) ? 0 : 1
    end
  end
end

::Modelist::CLI.start
