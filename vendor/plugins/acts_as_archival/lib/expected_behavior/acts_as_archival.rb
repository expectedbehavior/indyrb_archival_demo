module ExpectedBehavior
  module ActsAsArchival
    require 'digest/md5'

    ARCHIVED_CONDITIONS = 'archived_at IS NOT NULL AND archive_number IS NOT NULL'
    UNARCHIVED_CONDITIONS = { :archived_at => nil, :archive_number => nil }
    
    MissingArchivalColumnError = Class.new(ActiveRecord::ActiveRecordError) unless defined?(MissingArchivalColumnError) == 'constant' && MissingArchivalColumnError.class == Class

    
    def self.included(base) 
      base.extend ActMethods
    end

    module ActMethods
      def acts_as_archival
        unless included_modules.include? InstanceMethods
          include InstanceMethods 

          before_save :raise_if_not_archival
      
          named_scope :archived, :conditions => ARCHIVED_CONDITIONS
          named_scope :unarchived, :conditions => UNARCHIVED_CONDITIONS
          named_scope :archived_from_archive_number, lambda { |head_archive_number| {:conditions => ['archived_at IS NOT NULL AND archive_number = ?', head_archive_number] } }
       
          define_callbacks :before_archive, :after_archive
          define_callbacks :before_unarchive, :after_unarchive
        end 
      end 
    end
    
    module InstanceMethods
      def raise_if_not_archival
        missing_columns = []
        missing_columns << "archive_number" unless self.respond_to?(:archive_number)
        missing_columns << "archived_at" unless self.respond_to?(:archived_at)
        raise MissingArchivalColumnError.new("Add '#{missing_columns.join "', '"}' column(s) to '#{self.class.name}' to make it archival") unless missing_columns.blank?
      end
      
      def archived?
        self.archived_at? && self.archive_number
      end
      
      def archive(head_archive_number=nil)
        self.class.transaction do
          begin
            run_callbacks :before_archive
            unless self.archived?
              head_archive_number ||= Digest::MD5.hexdigest("#{self.class.name}#{self.id}")
              self.update_attributes!({:archived_at => DateTime.now, :archive_number => head_archive_number})
              self.archive_associations(head_archive_number)
            end
            run_callbacks :after_archive
          rescue
            raise ActiveRecord::Rollback
          end
        end
        self
      end
      
      def unarchive(head_archive_number=nil)
        self.class.transaction do
          begin
            run_callbacks :before_unarchive
            if self.archived?
              head_archive_number ||= self.archive_number
              self.unarchive_associations(head_archive_number)
              self.update_attributes!({:archived_at => nil, :archive_number => nil})
            end
            run_callbacks :after_unarchive
          rescue
            raise ActiveRecord::Rollback
          end
        end
        self
      end
      
      def archive_associations(head_archive_number)
        act_only_on_dependent_destroy_associations = Proc.new {|association| association.options[:dependent] == :destroy}
        act_on_all_archival_associations(head_archive_number, :archive => true, :association_options => act_only_on_dependent_destroy_associations)
      end
      
      def unarchive_associations(head_archive_number)
        act_on_all_archival_associations(head_archive_number, :unarchive => true)
      end
   
      # associations_options => lambda.new {|association| association.options[:dependent] == :destroy}
      def act_on_all_archival_associations(head_archive_number, options={})
        return if options.length == 0
        options[:association_options] ||= Proc.new { true }
        self.class.reflect_on_all_associations.each do |association|
          if association.klass.is_archival? && association.macro.to_s =~ /^has/ && options[:association_options].call(association)
            act_on_a_related_archival(association.klass, association.primary_key_name, id, head_archive_number, options)
          end
        end
      end
          
      def act_on_a_related_archival(klass, key_name, id, head_archive_number, options={})
        # puts "[klass => #{klass.name}, key_name => #{key_name}, :id => #{id}, :head_archive_number => #{head_archive_number}, options => #{options.inspect}]"
        return if options.length == 0 || (!options[:archive] && !options[:unarchive])
        if options[:archive]
          klass.unarchived.find(:all, :conditions => ["#{key_name} = ?", id]).each do |related_record|
            related_record.archive(head_archive_number)
          end
        else
          klass.archived.find(:all, :conditions => ["#{key_name} = ? AND archive_number = ?", id, head_archive_number]).each do |related_record|
            related_record.unarchive(head_archive_number)
          end
        end
      end
    end
  end
end
