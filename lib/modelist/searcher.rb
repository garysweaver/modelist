module Modelist
  class Searcher

    # Given a (partial) model/tablename/column/association name, finds all matching models/associations, e.g.
    #   Modelist::Searcher.find_all('bar')
    # would return the following if there were a model named Foobar, a table named moobars, a column named
    # barfoo_id in the users table, and an association named foobars on the Loo model:
    #   Models:
    #     Foobar (table: examples)
    #     Moo (table: moobars)
    #   Associations:
    #     User.barfoo (foreign key: barfoo_id)
    #     Loo.foobars
    def self.find_all(*args)
      # less-dependent extract_options!
      #options = args.last.is_a?(Hash) ? args.pop : {}
      raise ArgumentError.new("Please supply a search term") unless args.size != 0
      Rails.application.eager_load!
      models = []
      associations = []
      search_term = args[0].downcase
      ActiveRecord::Base.descendants.each do |m|
        if m.name.to_s.downcase[search_term] || m.name.to_s.underscore[search_term] || m.table_name.to_s.downcase[search_term] || m.table_name.to_s.underscore[search_term]
          val = "#{m.name} (table: #{m.table_name})"
          models << val unless models.include?(val)
        end
        m.reflect_on_all_associations.each do |a|
          if a.name.to_s.downcase[search_term] || a.name.to_s.underscore[search_term] || a.options.values.any?{|v| v.to_s.downcase[search_term] || v.to_s.underscore[search_term]}
            val = "#{m.name} (table: #{m.table_name}), association: #{a.name} (macro: #{a.macro.inspect}, options: #{a.options.inspect})"
            associations << val unless models.include?(val)
          end
        end
      end

      puts "Models:"
      models.each {|a| puts "  #{a}"}
      puts "Associations:"
      associations.each {|a| puts "  #{a}"}

      models.length > 0 || association.length > 0
    end
  end
end
