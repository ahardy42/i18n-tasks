# frozen_string_literal: true

require 'spec_helper'
require 'i18n/tasks/scanners/pattern_with_scope_scanner'

RSpec.describe 'method_return_scope_literal' do
  let(:scanner) do
    I18n::Tasks::Scanners::PatternWithScopeScanner.new
  end

  def stub_file_content(path, content)
    allow(scanner).to receive(:read_file).with(path).and_return(content)
  end

  it 'returns the string returned by the method' do
    stub_file_content('test', <<-RUBY)
      def translation_scope
        "bar"
      end
    RUBY

    expect(scanner.send(:method_return_scope_literal, 'test', 'translation_scope')).to eq('bar')
  end

  it 'returns nil if the method does not exist' do
    stub_file_content('test', <<-RUBY)
      def another_method
        "baz"
      end
    RUBY

    expect(scanner.send(:method_return_scope_literal, 'test', 'translation_scope')).to be_nil
  end

  it 'returns nil if the method does not return a string' do
    stub_file_content('test', <<-RUBY)
      def translation_scope
        123
      end
    RUBY

    expect(scanner.send(:method_return_scope_literal, 'test', 'translation_scope')).to be_nil
  end

  it 'returns nil if the file does not contain the method' do
    stub_file_content('test', <<-RUBY)
      # No methods here
    RUBY

    expect(scanner.send(:method_return_scope_literal, 'test', 'translation_scope')).to be_nil
  end

  it 'returns nil if the file is empty' do
    stub_file_content('test', '')

    expect(scanner.send(:method_return_scope_literal, 'test', 'translation_scope')).to be_nil
  end
end
