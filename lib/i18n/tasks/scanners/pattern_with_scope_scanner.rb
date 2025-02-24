# frozen_string_literal: true

require 'i18n/tasks/scanners/pattern_scanner'

module I18n::Tasks::Scanners
  # Scans for I18n.t(key, scope: ...) usages
  # both scope: "literal", and scope: [:array, :of, 'literals'] forms are supported
  # Caveat: scope is only detected when it is the first argument
  class PatternWithScopeScanner < PatternScanner
    protected

    def default_pattern
      # capture the first argument and scope argument if present
      /#{super}
      (?: \s*,\s* #{scope_arg_re} )? (?# capture scope in second argument )
      /x
    end

    # Given
    # @param [MatchData] match
    # @param [String] path
    # @return [String] full absolute key name with scope resolved if any
    def match_to_key(match, path, location)
      key   = super
      scope = match[1]
      if scope
        scope_parts = extract_literal_or_array_of_literals(scope, path)
        return nil if scope_parts.nil? || scope_parts.empty?

        "#{scope_parts.join('.')}.#{key}"
      else
        key unless match[0] =~ /\A\w/
      end
    end

    # parse expressions with literals and variable
    def first_argument_re
      /(?: (?: #{literal_re} ) | #{expr_re} )/x
    end

    # strip literals, convert expressions to #{interpolations}
    def strip_literal(val)
      if val =~ /\A[\w@]/
        "\#{#{val}}"
      else
        super(val)
      end
    end

    # scope: literal or code expression or an array of these
    def scope_arg_re
      /(?:
       :scope\s*=>\s* | (?# :scope => :home )
       scope:\s*        (?#    scope: :home )
      ) (\[[^\n)%#]*\]|[^\n)%#,]*|\w+\.\w+|#{expr_re})/x
    end

    # match a limited subset of code expressions (no parenthesis, commas, etc)
    def expr_re
      /[\w@.&|\s?!]+/
    end

    # scans for method definitions and returns the string returned by the method
    def method_return_scope_literal(path, method_name)
      text = read_file(path)
      return nil unless text

      # Regex pattern to match a method definition and capture the returned string
      pattern = /def\s+#{Regexp.escape(method_name)}\s*\n\s*"([^"]+)"\s*\n\s*end/

      match = text.match(pattern)
      match ? match[1] : nil
    end

    # extract literal, array of literals, or method call without arguments
    # returns nil on any other input
    # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity
    def extract_literal_or_array_of_literals(s, path)
      literals = []
      braces_stack = []
      acc = []
      consume_literal = proc do
        acc_str = acc.join
        if acc_str =~ literal_re
          literals << strip_literal(acc_str)
          acc = []
        elsif acc_str =~ expr_re
          lit = method_return_scope_literal(path, acc_str)
          if lit
            literals << lit
            acc = []
          else
            return nil
          end
        else
          return nil
        end
      end
      s.each_char.with_index do |c, i|
        if c == '['
          return nil unless braces_stack.empty?

          braces_stack.push(i)
        elsif c == ']'
          break
        elsif c == ','
          consume_literal.call
          break if braces_stack.empty?
        elsif c =~ VALID_KEY_CHARS || /['":]/ =~ c
          acc << c
        elsif c != ' '
          return nil
        end
      end
      consume_literal.call unless acc.empty?
      literals
    end
    # rubocop:enable Metrics/MethodLength,Metrics/PerceivedComplexity
  end
end
