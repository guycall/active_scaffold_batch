module ActiveScaffold::Actions
  module BatchCreate

    def self.included(base)
      base.before_filter :batch_create_authorized_filter, :only => [:batch_new, :batch_create]
      base.helper_method :batch_create_values
      base.helper_method :batch_create_by_column
      base.helper_method :batch_create_by_records
    end

    def batch_new
      do_batch_new
      respond_to_action(:batch_new)
    end

    def batch_add
      do_batch_add
      respond_to_action(:batch_add)
    end

    def batch_create
      batch_action
    end

    
    protected
    def batch_new_respond_to_html
      if batch_successful?
        render(:action => 'batch_create')
      else
        return_to_main
      end
    end

    def batch_new_respond_to_js
      render(:partial => 'batch_create_form')
    end

    def batch_add_respond_to_js
      render
    end

    def batch_create_values
      @batch_create_values || {}
    end

    def batch_create_by_records
      @batch_create_by_records || []
    end

    def batch_create_respond_to_html
      if params[:iframe]=='true' # was this an iframe post ?
        do_refresh_list
        responds_to_parent do
          render :action => 'on_batch_create.js', :layout => false
        end
      else # just a regular post
        if batch_successful?
          flash[:info] = as_(:created_model, :model => @record.to_label)
          return_to_main
        else
          render(:action => 'batch_create')
        end
      end
    end

    def batch_create_respond_to_js
      do_refresh_list
      render :action => 'on_batch_create'
    end

    def do_batch_new
      self.successful = true
      do_new
      if batch_create_by_column
        if marked_records_parent
          batch_scope # that s a dummy call to remove batch_scope parameter
          column = active_scaffold_config.columns[batch_create_by_column.to_sym]
          @batch_create_by_records = column_plural_assocation_value_from_value(column, marked_records_parent)
        end
      else
        @scope = "[#{temporary_id}]"
      end
    end

    def do_batch_add
      @records = {}
      params[:num_records] ||= 1
      params[:num_records].to_i.times do
        @records[temporary_id] = do_new
      end
    end

    def marked_records_parent
      if @marked_records_parent.nil?
        @marked_records_parent = if params[:batch_create_by]
          session_parent = active_scaffold_session_storage(params[:batch_create_by])
          session_parent[:marked_records] || Set.new
        else
          false
        end
      end
      @marked_records_parent
    end

    def before_do_batch_create
      if batch_create_by_column
        create_columns = active_scaffold_config.batch_create.columns
        @batch_create_values = create_attribute_values_from_params(create_columns, params[:record])
      else
        @batch_scope = 'multiple'
      end
    end

    def batch_create_listed
      case active_scaffold_config.batch_create.process_mode
      when :create then
        batch_create_by_records.each {|batch_record| create_record_in_batch(batch_record)}
      else
        Rails.logger.error("Unknown process_mode: #{active_scaffold_config.batch_create.process_mode} for action batch_create")
      end
    end
    alias_method :batch_create_marked, :batch_create_listed

    def batch_create_multiple
      @error_records = {}
      params[:record].each do |scope, record_hash|
        do_create(record_hash)
        error_records[scope] = @record unless successful?
      end
    end

    def new_batch_create_record(created_by)
      new_model
    end

    def create_record_in_batch(created_by)
      @successful = nil
      @record = new_batch_create_record(created_by)
      @record.send("#{batch_create_by_column.to_s}=", created_by)
      batch_create_values.each do |attribute, value|
        set_record_attribute(value[:column], attribute, value[:value])
      end

      if authorized_for_job?(@record)
        create_save
        if successful?
          marked_records_parent.delete(created_by.id) if batch_scope == 'MARKED' && marked_records_parent
        else
          error_records << @record
        end
      end
    end

    def batch_create_by_column
      active_scaffold_config.batch_create.default_batch_by_column
    end

    def create_attribute_values_from_params(columns, attributes)
      values = {}
      columns.each :for => model, :crud_type => :create, :flatten => true do |column|
        next unless attributes.has_key?(column.name)
        if column == batch_create_by_column.to_sym
          @batch_create_by_records = column_plural_assocation_value_from_value(column, attributes[column.name])
        else
          values[column.name] = {:column => column, :value => column_value_from_param_value(nil, column, attributes[column.name])}
        end
      end
      values
    end
    
    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def batch_create_authorized?(record = nil)
      authorized_for?(:crud_type => :create)
    end

    def batch_create_ignore?(record = nil)
      false
    end

    def override_batch_create_value(form_ui)
      method = "batch_create_value_for_#{form_ui}"
      method if respond_to? method
    end

    def create_ignore?
      super || batch_create_by_column.blank?
    end

    private

    def batch_create_authorized_filter
      link = active_scaffold_config.batch_create.link || active_scaffold_config.batch_create.class.link
      raise ActiveScaffold::ActionNotAllowed unless self.send(link.security_method)
    end
    def batch_new_formats
      (default_formats + active_scaffold_config.formats).uniq
    end
  end
end
