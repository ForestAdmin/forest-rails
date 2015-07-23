ActiveRecord::QueryMethods::WhereChain.class_eval do
  def or(*scopes)
    scopes_where_values = []
    scopes_bind_values  = []
    scopes.each do |scope|
      case scope
      when ActiveRecord::Relation
        scopes_where_values += scope.where_values
        scopes_bind_values += scope.bind_values
      when Hash
        temp_scope = @scope.model.where(scope)
        scopes_where_values += temp_scope.where_values
        scopes_bind_values  += temp_scope.bind_values
      end
    end
    scopes_where_values = scopes_where_values.inject(:or)
    @scope.where_values += [scopes_where_values]
    @scope.bind_values  += scopes_bind_values
    @scope
  end
end
