module Modelist
  class PathFinder
    DEFAULT_MAX_PATHS = 35

    def self.clean_underscore(classname)
      classname = classname[2..classname.length] if classname.start_with?('::')
      classname.underscore
    end

    def self.find_all(*args)
      raise ArgumentError.new("Please supply a search term") unless args.size != 0
      # less-dependent extract_options!
      options = args.last.is_a?(Hash) ? args.pop : {}
      
      from = args[0]
      to = args[1]

      puts "Checking for path from #{from} to #{to}..."
      relations = relationship_map_excluding(to)

      results = get_all_paths_via_iterative_depth_first_search(from, to, relations)
      puts
      puts

      matching_results = results.sort_by(&:length).reverse.collect{|arr|format_result_string(arr)}
      #TODO: make it actually not even search past N nodes
      if matching_results.length > 0
        puts "Paths from #{from} to #{to} (#{matching_results.length}):"
        # show the shortest path as the last item logged, for ease of use in CLI
        matching_results.each do |r|
          puts
          puts r
        end      
      else
        puts "No path found from #{from} to #{to}."
      end
      results
    end

    def self.relationship_map_excluding(exclude_name)
      Rails.application.eager_load!
      relations = {}
      
      m_to_a = {}
      ActiveRecord::Base.descendants.each do |m|
        m_to_a[m] = m.reflect_on_all_associations
      end

      m_to_a.each do |m,as|
        # don't try to link via composite primary keys until that is possible, which it isn't now afaik.
        next if m.primary_key.is_a?(Array)
        as.each do |association|
          c1_name = clean_underscore(m.name)
          next if c1_name == exclude_name
          #TODO: we could exclude c1/key that is "to"
          c1 = "#{c1_name}.#{association.name}"
          c2 = get_classname(association)
          if c2
            relations[c1] = clean_underscore(c2)
          end
        end unless as == nil
      end
      relations
    end

    # e.g.
    # from = 'model_name_1'
    # to = 'model_name_2'
    # directed_graph = {'model_name_3.assoc_name' => 'model_name_2', 'model_name_1.assoc_name' => 'model_name_3', 'model_name_2.assoc_name' => 'model_name_3', ...}
    # returns: [['model_name_1.assoc_name', 'model_name_3.assoc_name', 'model_name_2'], ...]
    def self.get_all_paths_via_iterative_depth_first_search(from, to, directed_graph)
      queue = directed_graph.keys.select {|k| k.split('.')[0] == from && directed_graph[k] != from}
      #puts "starting with #{queue.join(', ')}"
      queue.each {|k| print '+'; $stdout.flush}
      results = []
      processed_result_partials = {} # model.assoc to array of results
      current_node_list = []
      class_assocs_visited = []
      counts = [queue.length]

      while queue.length > 0
        #puts "queue(#{queue.length})=#{queue.inspect}"
        #visualize_queue(queue)
        this_class_assoc = queue.pop
        class_assocs_visited << this_class_assoc unless class_assocs_visited.include?(this_class_assoc)
        raise "FAILING! #{current_node_list[0].split('.')[0]} != #{from}" if current_node_list[0] && current_node_list[0].split('.')[0] != from
        print '-'; $stdout.flush
        next_class = directed_graph[this_class_assoc]
        #puts "processing #{this_class_assoc} => #{next_class}"
        current_node_list.push(this_class_assoc)
        #puts "current_node_list(#{current_node_list.length})=#{current_node_list.inspect}"
        #puts "counts: #{counts.join(',')}"
        
        step_back = true
        preprocessed_results = processed_result_partials[this_class_assoc]
        if preprocessed_results
          #puts "already processed #{this_class_assoc}"
          print '-'; $stdout.flush
          if preprocessed_results.length > 0
            results << (current_node_list + preprocessed_results)
            #raise "bug in preprocessed! should start with #{from} but have result #{format_result_string(results.last)}" if current_node_list[0].split('.')[0] != from
          end
        elsif next_class == to
          #puts "reached #{to} in #{current_node_list.length} steps"
          found_path = current_node_list + [next_class]
          results << found_path
          raise "oops! should start with #{from} but have result #{format_result_string(results.last)}" if current_node_list[0].split('.')[0] != from
          cache_found_path_partials(found_path, processed_result_partials)
        elsif !current_node_list.any?{|n| n.start_with?("#{next_class}.")}
          children_to_visit = directed_graph.select {|k,v| k.start_with?("#{next_class}.") && directed_graph[k] != from}.keys
          #puts "following (#{children_to_visit.length}): #{children_to_visit.join(', ')}"
          children_to_visit.each {|c|print '+'; $stdout.flush}
          if children_to_visit.length > 0
            step_back = false
            counts.push(children_to_visit.length)
            queue += children_to_visit
          end
        end

        back(current_node_list, counts, processed_result_partials, from) if step_back
      end

      #puts
      #puts
      #unvisited = directed_graph.keys - class_assocs_visited
      #puts "unvisited associations (#{unvisited.length}): #{unvisited.sort.join(', ')}"
      #puts

      results
    end

    def self.forward(current_node_list, this_class_assoc, counts, children_count)
      current_node_list.push(this_class_assoc)
      counts.push(children_count)
    end

    def self.back(current_node_list, counts, processed_result_partials, from)
      current_node_list.pop
      
      # if there is a count in the array less than two, keep removing them until they are gone
      while counts.last && counts.last < 2
        counts.pop
        c = current_node_list.pop

        # if this is direct/indirect circular reference, don't mark unprocessed origin as processed, because it isn't
        unless counts.size > 1 && c.start_with?("#{from}.")
          # completely processed this path, so don't process it again, and don't overwrite existing success if cached
          #puts "marking #{c} as done"
          processed_result_partials[c] = [] unless processed_result_partials[c]
        end
      end
      
      # either there are no counts, or we just need to decrement the last count
      if counts.last && counts.last > 1
        counts[counts.length-1] = counts[counts.length-1] - 1
      end
    end

    def self.cache_found_path_partials(found_path_arr, cache)
      (found_path_arr.length-2).downto(0) do |i|
        cache[found_path_arr[i]] = found_path_arr[i+1..found_path_arr.length-1] if found_path_arr.length > 1
      end
    end

    def self.format_result_string(*args)
      args.flatten.join(' -> ')
    end

    def self.get_classname(association)
      association.options[:class_name] || case association.macro
      when :belongs_to, :has_one
        association.name.to_s
      when :has_and_belongs_to_many, :has_many
        association.name.to_s.singularize
      end
    end

    #def self.visualize_queue(queue)
    #  puts
    #  puts "QUEUE:"
    #  puts
    #  last_root = queue[0].split('.')[0]
    #  queue.each do |item|
    #    if last_root.to_sym != item.split('.')[0].to_sym
    #      puts "   |" 
    #    end
    #    puts item
    #    last_root = item.split('.')[0].to_sym
    #  end
    #  puts
    #  puts "-------------"
    #end
  end
end
