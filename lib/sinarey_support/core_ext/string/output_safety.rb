require 'erb'
require 'sinarey_support/core_ext/kernel/singleton_class'

class ERB
  module Util

    HTML_ECP = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;', "'" => '&#39;' }
    JSON_ECP = { '&' => '\u0026', '>' => '\u003E', '<' => '\u003C' }
    HTML_ECP_ONCE = /["><']|&(?!([a-zA-Z]+|(#\d+));)/
    JSON_ECP_REGEXP = /[&"><]/

    def html_escape_once(s)
      result = s.to_s.gsub(HTML_ECP_ONCE, HTML_ECP)
      s.html_safe? ? result.html_safe : result
    end

    module_function :html_escape_once

    def json_escape(s)
      result = s.to_s.gsub(JSON_ECP_REGEXP, JSON_ECP)
      s.html_safe? ? result.html_safe : result
    end

    module_function :json_escape

    def sinarey_escape(value)
      if value.html_safe?
        value.to_s
      else
        value.to_s.gsub(/[&"'><]/, HTML_ECP)
      end
    end

    module_function :sinarey_escape

  end
end

class Object
  def html_safe?
    false
  end
end

class Numeric
  def html_safe?
    true
  end
end

class TrueClass
  def html_safe?
    true
  end
end

class FalseClass
  def html_safe?
    true
  end
end

class NilClass
  def html_safe?
    true
  end
end

module SinareySupport #:nodoc:
  class SafeBuffer < String
    UNSAFE_STRING_METHODS = %w(
      capitalize chomp chop delete downcase gsub lstrip next reverse rstrip
      slice squeeze strip sub succ swapcase tr tr_s upcase prepend
    )

    alias_method :original_concat, :concat
    private :original_concat

    class SafeConcatError < StandardError
      def initialize
        super 'Could not concatenate to the buffer because it is not html safe.'
      end
    end

    def [](*args)
      if args.size < 2
        super
      else
        if html_safe?
          new_safe_buffer = super
          new_safe_buffer.instance_eval { @html_safe = true }
          new_safe_buffer
        else
          to_str[*args]
        end
      end
    end

    def safe_concat(value)
      raise SafeConcatError unless html_safe?
      original_concat(value)
    end

    def initialize(*)
      @html_safe = true
      super
    end

    def initialize_copy(other)
      super
      @html_safe = other.html_safe?
    end

    def clone_empty
      self[0, 0]
    end

    def concat(value)
      if !html_safe? || value.html_safe?
        super(value)
      else
        super(ERB::Util.h(value))
      end
    end
    alias << concat

    def +(other)
      dup.concat(other)
    end

    def %(args)
      args = Array(args).map do |arg|
        if !html_safe? || arg.html_safe?
          arg
        else
          ERB::Util.h(arg)
        end
      end

      self.class.new(super(args))
    end

    def html_safe?
      defined?(@html_safe) && @html_safe
    end

    def to_s
      self
    end

    def to_param
      to_str
    end

    def encode_with(coder)
      coder.represent_scalar nil, to_str
    end

    UNSAFE_STRING_METHODS.each do |unsafe_method|
      if 'String'.respond_to?(unsafe_method)
        class_eval <<-EOT, __FILE__, __LINE__ + 1
          def #{unsafe_method}(*args, &block)       # def capitalize(*args, &block)
            to_str.#{unsafe_method}(*args, &block)  #   to_str.capitalize(*args, &block)
          end                                       # end

          def #{unsafe_method}!(*args)              # def capitalize!(*args)
            @html_safe = false                      #   @html_safe = false
            super                                   #   super
          end                                       # end
        EOT
      end
    end
  end
end

class String
  def html_safe
    SinareySupport::SafeBuffer.new(self)
  end
end
