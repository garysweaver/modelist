module Modelist
  class CircularRefChecker

    # Check refs on all models or models specified, e.g.
    #   Modelist::CircularRefChecker.test_models
    # or
    #   Modelist::CircularRefChecker.test_models(:my_model, :some_other_model)
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
          raise e
        end

        next unless model_class.ancestors.include?(ActiveRecord::Base)
        models << model_class
      end

      models.each do |model_class|
        test_model(model_class, results)
      end

      if results[:circles].nil? || results[:circles].size == 0
        unless Modelist.quiet?
          puts
          puts "No circular dependencies."
          puts
        end
        return true
      end

      if !Modelist.quiet? || options[:output_file]
        totals = {}
        results[:circles_sorted].each do |arr|
          arr.each do |key|
            totals[key] = 0 unless totals[key]
            totals[key] = totals[key] + 1
          end
        end

        unless Modelist.quiet?
          puts  "The following non-nullable foreign keys used in ActiveRecord model associations are involved in circular dependencies:"
          results[:circles].sort.each do |c|
            puts
            puts "#{c}"
          end
          puts
          puts
          puts "Distinct foreign keys involved in a circular dependency:"
          puts
          results[:offenders].sort.each do |c|
            puts "#{c[0]}.#{c[1]}"
          end
          puts
          puts
          puts "Foreign keys by number of circular dependency chains involved with:"
          puts
          totals.sort_by {|k,v| v}.reverse.each do |arr|
            c = arr[0]
            t = arr[1]
            puts "#{t} (out of #{results[:circles_sorted].size}): #{c[0]}.#{c[1]} -> #{c[2]}"
          end
          puts
        end

        if options[:output_file]
          File.open(options[:output_file], "w") do |f|
            f.puts  "The following non-nullable foreign keys used in ActiveRecord model associations are involved in circular dependencies:"
            results[:circles].sort.each do |c|
              f.puts
              f.puts "#{c}"
            end
            f.puts
            f.puts
            f.puts "Distinct foreign keys involved in a circular dependency:"
            f.puts
            results[:offenders].sort.each do |c|
              f.puts "#{c[0]}.#{c[1]}"
            end
            f.puts
            f.puts
            f.puts "Foreign keys by number of circular dependency chains involved with:"
            f.puts
            totals.sort_by {|k,v| v}.reverse.each do |arr|
              c = arr[0]
              t = arr[1]
              f.puts "#{t} (out of #{results[:circles_sorted].size}): #{c[0]}.#{c[1]} -> #{c[2]}"
            end
            f.puts
          end
        end
      end

      return false
    end

    # Get hash of circular reference information about associations tree on model specified, e.g.
    #   Modelist::CircularRefChecker.test_model(:my_model)
    # Also can take model class:
    #   Modelist::CircularRefChecker.test_model(MyModel)
    def self.test_model(model_class, results = nil, model_and_association_names = [])
      model_class = model_class.to_s.camelize.constantize unless model_class.is_a?(Class)

      results ||= {}
      results[:offenders] ||= []
      results[:circles_sorted] ||= []
      results[:circles] ||= []
      results[:selected_offenders] ||= []

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

        if required
          key = [model_class.table_name.to_sym, reflection.foreign_key.to_sym, next_class.table_name.to_sym]
          if model_and_association_names.include?(key)
            results[:offenders] << model_and_association_names.last unless results[:offenders].include?(model_and_association_names.last)
            short = model_and_association_names.dup
            # drop all preceding keys that have nothing to do with the circle
            (short.index(key)).times {short.delete_at(0)}
            sorted = short.sort
            unless results[:circles_sorted].include?(sorted)
              results[:circles_sorted] << sorted
              results[:circles] << "#{(short + [key]).collect{|b|"#{b[0]}.#{b[1]}"}.join(' -> ')}".to_sym
            end
          else
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
