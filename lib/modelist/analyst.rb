module Modelist
  class Analyst

    # Check refs on all models or models specified, e.g.
    #   Modelist::Analyst.find_model_requirements
    # or
    #   Modelist::Analyst.find_model_requirements(:my_model, :some_other_model)
    def self.find_required_models(*args)
      # less-dependent extract_options!
      #options = args.last.is_a?(Hash) ? args.pop : {}
      raise ArgumentError.new("Please supply one or more models") unless args.size > 0
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
          raise e
        end

        next unless model_class.ancestors.include?(ActiveRecord::Base)
        models << model_class
      end

      models.each do |model_class|
        test_model(model_class, results)
      end

      unless Modelist.quiet? || !results[:required_models]
        puts "Required models:"
        puts
        results[:required_models].collect{|c|c.name}.sort.each do |c|
          puts "#{c}"
        end
        puts
      end

      return results[:required_models] ? results[:required_models] : []
    end

    # Get hash of required model information including non-nullable or validation presence associations throughout associations tree for model specified, e.g.
    #   Modelist::Analyst.test_model(:my_model)
    # Also can take model class:
    #   Modelist::Analyst.test_model(MyModel)
    def self.test_model(model_class, results = nil, model_and_association_names = [])
      model_class = model_class.to_s.camelize.constantize unless model_class.is_a?(Class)

      results ||= {}
      results[:required_models] ||= []
      results[:required_models] << model_class unless results[:required_models].include?(model_class)

      model_class.reflections.collect {|association_name, reflection|
        puts "warning: #{model_class}'s association #{reflection.name}'s foreign_key was nil. can't check." unless reflection.foreign_key || Modelist.quiet?
        assc_sym = reflection.name.to_sym
        
        begin
          next_class = reflection.class_name.constantize
        rescue => e
          puts "Problem in #{model_class.name} with association: #{reflection.macro} #{assc_sym.inspect} which refers to class #{reflection.class_name}" unless Modelist.quiet?
          raise e
        end

        has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
        required = false
        if reflection.macro == :belongs_to
          # note: supports composite_primary_keys gem which stores primary_key as an array
          foreign_key_is_also_primary_key = Array.wrap(model_class.primary_key).collect{|pk|pk.to_sym}.include?(reflection.foreign_key.to_sym)
          is_not_null_fkey_that_is_not_primary_key = model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym && !foreign_key_is_also_primary_key}
          required = is_not_null_fkey_that_is_not_primary_key || has_presence_validator
        else
          # no nullable metadata on column if no foreign key in this table. we'd figure out the null requirement on the column if inspecting the child model
          required = has_presence_validator
        end

        puts "#{model_class.name}.#{association_name} #{required ? 'required' : 'not required'}"

        if required
          key = [model_class.table_name.to_sym, reflection.foreign_key.to_sym, next_class.table_name.to_sym]
          unless model_and_association_names.include?(key)
            model_and_association_names << key
            test_model(next_class, results, model_and_association_names)
          end
        end
      }

      model_and_association_names.pop
      results
    end
  end
end
