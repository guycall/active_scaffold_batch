module ActiveScaffold::Actions
  module BatchCreate

    def self.included(base)
      base.before_filter :batch_create_authorized_filter, :only => [:batch_new, :batch_create]
      base.verify :method => [:post, :put],
                  :only => :batch_create,
                  :redirect_to => { :action => :index }
      base.helper_method :batch_create_values
      base.helper_method :batch_create_by_column
    end

    def batch_new
      do_batch_new
      respond_to_action(:batch_new)
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

    def batch_create_values
      @batch_create_values || {}
    end

    def batch_records
      @batch_records || []
    end

    def batch_create_respond_to_html
      if params[:iframe]=='true' # was this an iframe post ?
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
      render :action => 'on_batch_create'
    end

    def do_batch_new
      self.successful = true
      do_new
    end

    def before_do_batch_create
      create_columns = active_scaffold_config.batch_create.columns
      @batch_create_values = attribute_values_from_params(create_columns, params[:record])
    end

    # in case of an error we have to prepare @record object to have assigned all
    # defined batch_update values, however, do not set those ones with an override
    # these ones will manage on their own
    def prepare_error_record
      do_new
      batch_create_values.each do |attribute, value|
        form_ui = colunm_form_ui(value[:column])
        set_record_attribute(value[:column], attribute, value[:value]) unless form_ui && override_batch_create_value?(form_ui)
      end
    end

    def batch_create_listed
      case active_scaffold_config.batch_create.process_mode
      when :create then
        batch_records.each {|batch_record| create_record(batch_record)}
      else
        Rails.logger.error("Unknown process_mode: #{active_scaffold_config.batch_create.process_mode} for action batch_create")
      end
      
    end

    def batch_create_marked
      case active_scaffold_config.batch_create.process_mode
      when :create then
        #active_scaffold_config.model.marked.each {|record| create_record(record) if authorized_for_job?(record)}
      else
        Rails.logger.error("Unknown process_mode: #{active_scaffold_config.batch_create.process_mode} for action batch_create")
      end
    end

    def create_record(batch_record)
      @successful = nil
      @record = new_model
      @record.send("#{batch_create_by_column.to_s}=", batch_record)
      batch_create_values.each do |attribute, value|
        set_record_attribute(value[:column], attribute, value[:value])
      end

      if authorized_for_job?(@record)
        create_save
        if successful?
          @record.marked = false if batch_scope == 'MARKED'
        else
          error_records << @record
        end
      end
    end

    def set_record_attribute(column, attribute, value)
      form_ui = colunm_form_ui(column)
      if form_ui && override_batch_create_value?(form_ui)
        @record.send("#{attribute}=", send(override_batch_create_value(form_ui), column, @record, value))
      else
        @record.send("#{attribute}=", value)
      end
    end

    def colunm_form_ui(column)
      form_ui = column.form_ui
      form_ui = column.column.type if form_ui.nil? && column.column
    end

    def batch_create_by_column
      active_scaffold_config.batch_create.default_batch_by_column
    end


    def attribute_values_from_params(columns, attributes)
      values = {}
      columns.each :for => active_scaffold_config.model.new, :crud_type => :create, :flatten => true do |column|
        if batch_create_by_column == column.name
          @batch_records = column_plural_assocation_value_from_value(column, attributes[column.name])
        else
          values[column.name] = {:column => column, :value => column_value_from_param_value(nil, column, attributes[column.name])}
        end if attributes.has_key?(column.name)
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

    def override_batch_create_value?(form_ui)
      respond_to?(override_batch_create_value(form_ui))
    end

    def override_batch_create_value(form_ui)
      "batch_create_value_for_#{form_ui}"
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