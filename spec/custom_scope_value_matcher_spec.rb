# frozen_string_literal: true

require 'spec_helper'
require 'i18n/tasks/scanners/ast_matchers/custom_scope_value_matcher'

RSpec.describe 'CustomScopeValueMatcher' do
  let(:matcher) do
    I18n::Tasks::Scanners::AstMatchers::CustomScopeValueMatcher.new
  end

  def stub_file_content(path, content)
    allow(matcher).to receive(:read_file).with(path).and_return(content)
  end

  describe 'convert_to_key_occurrences' do
    it 'matches a literal scope' do
      stub_file_content('test', '= t :key, scope: "scope"')
      send_node = parse_ruby('= t :key, scope: "scope"').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences.map(&:key)).to eq(['scope.key'])
    end

    it 'matches a scope that is a method call' do 
        stub_file_content 'test', <<-RUBY
        = t :key, scope: translation_scope

        def translation_scope
          "bar"
        end
        RUBY

      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences.map(&:key)).to eq(['bar.key'])
    end

    it 'matches a scope that is a variable' do 
        stub_file_content 'test', <<-RUBY
            translation_scope = "bar"
            = t :key, scope: translation_scope
            RUBY

      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences.map(&:key)).to eq(['bar.key'])
    end

    it 'returns nil if the method does not exist' do 
        stub_file_content 'test', <<-RUBY
            = t :key, scope: translation_scope

            def another_method
              "baz"
            end
            RUBY

      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences).to be_nil
    end

    it 'returns nil if the variable does not exist' do 
        stub_file_content 'test', <<-RUBY
            = t :key, scope: translation_scope
            RUBY

      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences).to be_nil
    end

    it 'returns nil if the method does not return a string' do 
        stub_file_content 'test', <<-RUBY
            = t :key, scope: translation_scope
            
            def translation_scope
              123
            end
            RUBY

      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences).to be_nil
    end

    it 'returns nil if the file does not contain the method' do 
        stub_file_content 'test', <<-RUBY
            # No methods here
            RUBY

      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences).to be_nil
    end

    it 'returns nil if the file is empty' do
      stub_file_content('test', '')
      send_node = parse_ruby('= t :key, scope: translation_scope').children.first
      occurrences = matcher.convert_to_key_occurrences(send_node, :t, location: send_node.loc)
      expect(occurrences).to be_nil
    end
  end
end
