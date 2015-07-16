module ForestRails
  class ResourcesController < ForestRails::ApplicationController

    before_filter :find_resource
    before_filter :define_serializers

    def index
      if params[:search]
        records = @resource.where(search_query)
      else
        records = @resource.all
      end

      if @resource.column_names.include?('created_at')
        records = records.order('created_at DESC')
      elsif @resource.column_names.include?('id')
        records = records.order('id DESC')
      end

      render json: records.limit(10), each_serializer: @serializer,
        adapter: :json_api
    end

    def show
      render json: @resource.find(params[:id]), serializer: @serializer,
        adapter: :json_api
    end

    def create
      record = @resource.create!(resource_params)
      render json: record, serializer: @serializer, adapter: :json_api
    end

    def update
      record = @resource.find(params[:id])
      record.update_attributes!(resource_params)
      render json: record, serializer: @serializer, adapter: :json_api
    end

    def destroy
      @resource.destroy_all(id: params[:id])
      render nothing: true, status: 204
    end

    private

    def find_resource
      @resource_plural_name = params[:resource]
      @resource_singular_name = @resource_plural_name.singularize
      @resource_class_name = @resource_singular_name.classify

      begin
        @resource = @resource_class_name.constantize
      rescue
      end

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found
      end
    end

    def define_serializers
      @serializer = SerializerFactory.new.serializer_for(@resource)
    end

    def resource_params
      ResourceDeserializer.new(@resource, params).perform
    end

    def search_query
      query = ""

      @resource.columns.each do |column|
        if column.name == 'id'
          query += ' OR ' unless query.empty?
          query += "id = #{params[:search].to_i}"
        elsif column.type == :string
          query += ' OR ' unless query.empty?
          query += "lower(#{column.name}) LIKE '#{params[:search].downcase}%'"
        end
      end

      query
    end

  end
end
