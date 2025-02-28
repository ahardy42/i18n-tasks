# frozen_string_literal: true

require 'i18n/tasks/scanners/results/occurrence'

module I18n::Tasks::Scanners::AstMatchers
  class CustomScopeValueMatcher < BaseMatcher
    def convert_to_key_occurrences(send_node, _method_name, location: send_node.loc)
      scope_value_to_key_occurrences(send_node: send_node, location: location)
    end

    private

    def scope_value_to_key_occurrences(send_node:, location:)
      children = Array(send_node&.children)
      receiver = children[0]
      method_name = children[1]

      return unless method_name == :t && receiver.nil?

      args = children[2..-1]
      scope_arg = find_scope_arg(args)

      return unless scope_arg

      scope_value = extract_scope_value(scope_arg, location.expression.source_buffer.name)
      return unless scope_value

      key = "#{scope_value}.#{extract_string(args[0])}"
      [
        key,
        I18n::Tasks::Scanners::Results::Occurrence.from_range(
          raw_key: key,
          range: location.expression
        )
      ]
    end

    def find_scope_arg(args)
      args.find do |arg|
        arg.type == :hash && arg.children.any? { |pair| pair.children[0].children[0] == :scope }
      end
    end

    def extract_scope_value(scope_arg, file_path)
      scope_pair = scope_arg.children.find { |pair| pair.children[0].children[0] == :scope }
      scope_value_node = scope_pair.children[1]

      case scope_value_node.type
      when :str, :sym
        scope_value_node.children[0].to_s
      when :lvar, :ivar
        find_variable_value(scope_value_node, file_path)
      when :send
        find_method_return_value(scope_value_node, file_path)
      else
        nil
      end
    end

    def find_variable_value(var_node, file_path)
      var_name = var_node.children[0].to_s
      text = read_file(file_path)
      return nil unless text

      pattern = /#{Regexp.escape(var_name)}\s*=\s*"([^"]+)"/
      match = text.match(pattern)
      match ? match[1] : nil
    end

    def find_method_return_value(method_node, file_path)
      method_name = method_node.children[1].to_s
      text = read_file(file_path)
      return nil unless text

      pattern = /def\s+#{Regexp.escape(method_name)}\s*\n\s*"([^"]+)"\s*\n\s*end/
      match = text.match(pattern)
      match ? match[1] : nil
    end
  end
end
