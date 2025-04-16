# The "brick_links" patch -- this finds how every AR chain of association names
# relates back to an exact table correlation name chosen by AREL when the AST tree is
# walked.  For instance, from a Customer model there could be a join_tree such as
# { orders: { line_items: :product} }, which would end up recording three entries, the
# last of which for products would have a key of "orders.line_items.product" after
# having gone through two HMs and one BT.  AREL would have chosen a correlation name of
# "products", being able to use the same name as the table name because it's the first
# time that table is used in this query.  But let's see what happens if each customer
# also had a BT to a favourite product, referenced earlier in the join_tree like this:
# [:favourite_product, orders: { line_items: :product}] -- then the second reference to
# "products" would end up being called "products_line_items" in order to differentiate
# it from the first reference, which would have already snagged the simpler name
# "products".  It's essential that The Brick can find accurate correlation names when
# there are multiple JOINs to the same table.
module ForestLiana
  module ActiveRecordOverride
    module QueryMethods
      private

      if private_instance_methods.include?(:build_join_query) # AR 5.0 - 6.0
        alias _brick_build_join_query build_join_query
        def build_join_query(manager, buckets, *args) # , **kwargs)
          # %%% Better way to bring relation into the mix
          if (aj = buckets.fetch(:association_join, nil))
            aj.instance_variable_set(:@relation, self)
          end

          _brick_build_join_query(manager, buckets, *args) # , **kwargs)
        end

      elsif private_instance_methods.include?(:select_association_list) # AR >= 6.1
        alias _brick_select_association_list select_association_list
        def select_association_list(associations, stashed_joins = nil)
          result = _brick_select_association_list(associations, stashed_joins)
          result.instance_variable_set(:@relation, self)
          result
        end
      end
    end
    module Associations
      require 'active_record/associations/join_dependency'
      module JoinDependency
        # An intelligent .eager_load() and .includes() that creates t0_r0 style aliases only for the columns
        # used in .select().  To enable this behaviour, include the flag :_brick_eager_load as the first
        # entry in your .select().
        # More information:  https://discuss.rubyonrails.org/t/includes-and-select-for-joined-data/81640
        def apply_column_aliases(relation)
          debugger
          if !(@join_root_alias = relation.select_values.empty?) &&
            relation.select_values.first.to_s == '_brick_eager_load'
            debugger
            relation.select_values.shift
            used_cols = {}
            # Find and expand out all column names being used in select(...)
            new_select_values = relation.select_values.map(&:to_s).each_with_object([]) do |col, select|
              unless col.include?(' ') # Pass it through if it's some expression (No chance for a simple column reference)
                col = if (col_parts = col.split('.')).length == 1
                  [col]
                else
                  [col_parts[0..-2].join('.'), col_parts.last]
                end
                used_cols[col] = nil
              end
              select << col
            end

            if new_select_values.present?
              relation.select_values = new_select_values
            else
              relation.select_values.clear
            end

            @aliases ||= ActiveRecord::Associations::JoinDependency::Aliases.new(join_root.each_with_index.map do |join_part, i|
              join_alias = join_part.table&.table_alias || join_part.table_name
              keys = [join_part.base_klass.primary_key] # Always include the primary key

              # # %%% Optional to include all foreign keys:
              # keys.concat(join_part.base_klass.reflect_on_all_associations.select { |a| a.belongs_to? }.map(&:foreign_key))
              # Add foreign keys out to referenced tables that we belongs_to
              join_part.children.each { |child| keys << child.reflection.foreign_key if child.reflection.belongs_to? }

              # Add the foreign key that got us here -- "the train we rode in on" -- if we arrived from
              # a has_many or has_one:
              if join_part.is_a?(ActiveRecord::Associations::JoinDependency::JoinAssociation) &&
                !join_part.reflection.belongs_to?
                keys << join_part.reflection.foreign_key
              end
              keys = keys.compact # In case we're using composite_primary_keys
              j = 0
              columns = join_part.column_names.each_with_object([]) do |column_name, s|
                # Include columns chosen in select(...) as well as the PK and any relevant FKs
                if used_cols.keys.find { |c| (c.length == 1 || c.first == join_alias) && c.last == column_name } ||
                  keys.find { |c| c == column_name }
                  s << ActiveRecord::Associations::JoinDependency::Aliases::Column.new(column_name, "t#{i}_r#{j}")
                end
                j += 1
              end
              ActiveRecord::Associations::JoinDependency::Aliases::Table.new(join_part, columns)
            end)
            relation.select_values.clear
          end

          relation._select!(-> { aliases.columns })
        end

        private

        # # %%% Pretty much have to flat-out replace this guy (I think anyway)
        # # Good with Rails 5.2.4 through 7.1 on this
        # # Ransack gem includes Polyamorous which replaces #build in a different way (which we handle below)
        # if Gem::Dependency.new('ransack').matching_specs.empty?
        #   def build(associations, base_klass, root = nil, path = '')
        #     root ||= associations
        #     associations.map do |name, right|
        #       reflection = find_reflection base_klass, name
        #       reflection.check_validity!
        #       reflection.check_eager_loadable! if reflection.respond_to?(:check_eager_loadable!) # Used in AR >= 4.2
        #
        #       if reflection.polymorphic?
        #         raise EagerLoadPolymorphicError.new(reflection)
        #       end
        #
        #       link_path = path.blank? ? name.to_s : path + ".#{name}"
        #       ja = JoinAssociation.new(reflection, build(right, reflection.klass, root, link_path))
        #       ja.instance_variable_set(:@link_path, link_path) # Make note on the JoinAssociation of its AR path
        #       ja.instance_variable_set(:@assocs, root)
        #       ja
        #     end
        #   end
        # end

        # No matter if it's older or newer Rails, now extend so that we can associate AR links to table_alias names
        if ActiveRecord.version < ::Gem::Version.new('6.1')
          alias _brick_table_aliases_for table_aliases_for
          def table_aliases_for(parent, node)
            result = _brick_table_aliases_for(parent, node)
            # Capture the table alias name that was chosen
            if (relation = node.instance_variable_get(:@assocs)&.instance_variable_get(:@relation))
              link_path = node.instance_variable_get(:@link_path)
              relation.brick_links(false)[link_path] = result.first.table_alias || result.first.table_name
            end
            result
          end
        else # Same idea but for Rails >= 6.1
          # alias _brick_make_constraints make_constraints
          def make_constraints(parent, child, join_type)
            result = super(parent, child, join_type)

            # Capture the table alias name that was chosen
            if (relation = child.instance_variable_get(:@assocs)&.instance_variable_get(:@relation))
              link_path = child.instance_variable_get(:@link_path)
              relation.brick_links(false)[link_path] = if child.table.is_a?(Arel::Nodes::TableAlias)
                child.table.right
              else
                # Was:  result.first&.left&.table_alias || child.table_name
                child.table.table_alias || child.table_name
              end
            end
            result
          end
        end
      end
    end
  end

end
