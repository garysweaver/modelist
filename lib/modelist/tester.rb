module Modelist
  class Tester

    # Check refs on all models or models specified, e.g.
    #   Modelist::Tester.test_models
    # or
    #   Modelist::Tester.test_models(:my_model, :some_other_model)
    def self.test_models(*args)
      # less-dependent extract_options!
      options = args.last.is_a?(Hash) ? args.pop : {}
      results = {}
      models = []
      included_models = args.compact.collect{|m|m.to_sym}
      puts "Checking models: #{included_models.collect{|m|m.inspect}.join(', ')}" if !Modelist.quiet? && included_models.size > 0
      Dir[File.join('app','models','*.rb').to_s].each do |filename|
        model_name = File.basename(filename).sub(/.rb$/, '')
        next if included_models.size > 0 && !included_models.include?(model_name.to_sym)
        load File.join('app','models',"#{model_name}.rb")
        
        begin
          model_class = model_name.camelize.constantize
        rescue => e
          puts "Problem in #{model_name.camelize}" unless Modelist.quiet?
          results[:failures] << "FAILED: #{model_name}\n\n---\n\n#{filename}\n---\n#{formatted_errors.join("\n")}\n\n"
          results[:failed] << model_class_name
          raise e
        end

        next unless model_class.ancestors.include?(ActiveRecord::Base)
        models << model_class
      end

      models.each do |model_class|
        test_model(model_class, results)
      end

      unless Modelist.quiet?
        puts "Done testing"
        puts ""
        puts ""

        # Write warnings to file and console
        if results[:failures] && results[:failures].size > 0
          unless Modelist.quiet? 
            puts "Failures:"
            puts
            results[:failures].sort.each do |failure|
              puts *(failure.split('\n'))
            end
          end
          
          if options[:output_file]
            File.open(options[:output_file], "w") do |f|
              f.puts "Failures:"
              f.puts
              results[:failures].sort.each do |failure|
                f.puts *(failure.split('\n'))
              end
            end

            unless Modelist.quiet?
              puts ""
              puts "Errors in #{ERRORS_FILE}"
            end
          end
        end

        unless Modelist.quiet? || !results[:passed]
          puts
          puts "Passed (#{results[:passed].size}):"
          puts "---"
          results[:passed].each do |s|
            puts s
          end
          puts
          puts "Warnings (#{results[:warnings].size}):"
          puts "---"
          results[:warnings].each do |s|
            puts s
          end
          puts
          puts "Failed (#{results[:failed].size}):"
          puts "---"
          results[:failed].each do |s|
            puts s
          end
        end
      end

      return results[:failed] ? results[:failed].size > 0 : true
    end

    # Test and get hash of information about model specified, e.g.
    #   Modelist::Tester.test_associations(:my_model)
    # Also can take model class:
    #   Modelist::Tester.test_associations(MyModel)
    def self.test_model(model_class, results = nil)
      model_class = model_class.to_s.camelize.constantize unless model_class.is_a?(Class)

      results ||= {}
      results[:passed] ||= []
      results[:warnings] ||= []
      results[:failed] ||= []
      results[:failures] ||= []

      puts "Testing #{model_class}"
      method_name_to_exception = {}
      if model_class
        
        model = nil

        begin          
          model = model_class.first
          puts "#{model_class}.first = #{model.inspect}"
          if model.nil?
            results[:warnings] << "#{model_class.name}.first was nil. Assuming there is no data in the associated table, but please verify."
          end
        rescue Exception => e
          method_name_to_exception["#{model_class.name}.first"] = e
        end

        if model
          begin          
            model = model_class.last
            puts "#{model_class}.last = #{model.inspect}"
            if model.nil?
              results[:warnings] << "#{model_class.name}.last was nil."
            end
          rescue Exception => e
            method_name_to_exception["#{model_class.name}.last"] = e
          end
        end

        if model
          attrs = model.attributes.keys
          attrs.each do |attr|
            begin
              result = model.read_attribute(attr)
              if result.is_a? Array
                size = result.size
                puts "#{model_class.name.underscore}.#{attr}.size = #{size}"
              else
                puts "#{model_class.name.underscore}.#{attr} = #{result}"
              end
            rescue Exception => e
              method_name_to_exception["#{model_class.name}.#{attr}"] = e
            end
          end
        end

        model_class.reflections.collect do |association_name, reflection|
          begin
            reflection.class_name
          rescue Exception => e
            method_name_to_exception["#{model_class.name}'.{association_name}'s reflection class_name method"] = e
            next
          end

          model = model_class.new unless model
          begin
            value = model.send(association_name.to_sym)
            if value.nil?
              #results[:warnings] << "(ignore) #{model_class_name}.#{association_name} was nil"
            elsif (value.is_a?(Array) && value.size == 0)
              #results[:warnings] << "(ignore) #{model_class_name}.#{association_name} was empty"
            end
          rescue Exception => e
            method_name_to_exception["#{model_class.name}.last.#{association_name}"] = e
          end
        end
      end

      if method_name_to_exception.size > 0
        formatted_errors = method_name_to_exception.keys.collect{|method_name|"#{method_name}: #{method_name_to_exception[method_name].message}\n#{method_name_to_exception[method_name].backtrace.join("\n")}\n---\n"}
        results[:failures] << "FAILED: #{model_class.name}\n\n---\n#{formatted_errors.join("\n")}\n\n"
        results[:failed] << model_class.name
      else
        results[:passed] << model_class.name
      end

      results
    end
  end
end
