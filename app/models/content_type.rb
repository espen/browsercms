class ContentType < ActiveRecord::Base

  attr_accessor :group_name
  belongs_to :content_type_group
  validates_presence_of :content_type_group
  before_validation :set_content_type_group
  
  named_scope :named, lambda{|name| {:conditions => ['content_types.name = ?', name]}}
  
  named_scope :connectable, 
    :include => :content_type_group,
    :conditions => ['content_type_groups.name != ?', 'Categorization'],
    :order => 'content_types.priority, content_types.name'
  
  def self.list
    all.map { |f| f.name.underscore.to_sym }
  end
   
  # Given a 'key' like 'html_blocks' or 'portlet'
  # Raises exception if nothing was found.
  def self.find_by_key(key)
    class_name = key.singularize.classify
    content_type = find_by_name(class_name)
    if content_type.nil?
      if class_name.constantize.ancestors.include?(Portlet)
        content_type = ContentType.new(:name => class_name)
        content_type.content_type_group = ContentTypeGroup.find_by_name('Core')
        content_type.freeze
        content_type
      else
        raise "Not a Portlet"
      end
    else
      content_type
    end
  rescue Exception
    raise "Couldn't find ContentType of class '#{class_name}'"    
  end
  
  def is_child_of?(content_type)
    name.constantize.ancestors.map{|c| c.name}.include?(content_type.name)  
  end
  
  def form
    model_class.respond_to?(:form) ? model_class.form : "cms/#{name.underscore.pluralize}/form"
  end
  
  def display_name
    model_class.respond_to?(:display_name) ? model_class.display_name : model_class.to_s.titleize
  end

  def display_name_plural
    model_class.respond_to?(:display_name_plural) ? model_class.display_name_plural : display_name.pluralize
  end

  def model_class
    name.tableize.classify.constantize
  end
  
  def status
    "test"
  end
  
  def first_default_columns_for_index
    columns = [
      {:id => "id", :name => "ID", :field => "id", :width => 10, :sortable => true, :filter => :free, :resizeable => false},
      {:id => "name", :name => "Name", :field => "name", :width => 120, :cssClass => "block-name", :sortable => true, :filter => :free, :resizeable => true}
    ]
    
    columns
  end
  
  def last_default_columns_for_index
    columns = []
    
    columns << {:id => "updated_at", :name => "Updated On", :field => :updated_on_string, :sortable => true, :filter => :free, :resizeable => true} if(model_class.respond_to?(:updated_at))
    columns << {:name => "Used", :field => "connected_pages.count", :id => "connected_pages_count", :filter => :free, :width => 15 } if(model_class.connectable?)
    columns << {:name => "Status", :field => "status", :id => "status", :filter => :select, :width => 20 } if(model_class.publishable?)
    
    columns
  end

  # Allows models to show additional columns when being shown in a list.
  def columns_for_index
    if(!@columns)
      columns = []
    
      if model_class.respond_to?(:columns_for_index)
        columns = model_class.columns_for_index
      end
    
      # Add default columns to the beginning of the column list
      self.first_default_columns_for_index.reverse.each do |column|
        if(!columns.select { |selected_column| selected_column[:id].to_s == column[:id]}.any?)
          columns.unshift(column)
        end
      end
    
      # Add default columns to the end of the column list
      self.last_default_columns_for_index.each do |column|
        if(!columns.select { |selected_column| selected_column[:id].to_s == column[:id]}.any?)
          columns.push(column)
        end
      end
      @columns = columns.flatten
    end
    @columns
  end
  
  def data_for_block(block)
    Rails.logger.debug columns_for_index.inspect
    result = columns_for_index.map do |column|
      method = column[:field].to_s
      [method.gsub(".", "_"), method.split(".").inject(block) { |memo, method| memo.send(method) }]
    end
    Hash[*result.flatten]
  end

  # Used in ERB for pathing
  def content_block_type
    name.pluralize.underscore
  end
  
  # This is used for situations where you want different to use a type for the list page
  # This is true for portlets, where you don't want to list all portlets of a given type,
  # You want to list all portlets
  def content_block_type_for_list
    if model_class.respond_to?(:content_block_type_for_list)
      model_class.content_block_type_for_list
    else
      content_block_type
    end
  end
  
  def set_content_type_group
    if group_name
      group = ContentTypeGroup.first(:conditions => {:name => group_name})
      self.content_type_group = group || build_content_type_group(:name => group_name)
    end
  end
  
end
