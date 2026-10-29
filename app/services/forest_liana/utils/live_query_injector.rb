require 'strscan'

module ForestLiana
  module Utils
    class LiveQueryInjector
      PLACEHOLDER = Regexp.union(ContextVariablesInjector::PLACEHOLDER, '?')
      VERBATIM_VALUE = /\A(?:\d+(?:\.\d+)?(?:,\d+(?:\.\d+)?)*|true|false)\z/i
      CHARACTERS_CLOSING_QUOTED_TEXT = /["`'\\$\]\r\n\0]/
      LINE_COMMENT = /--[^\n]*/
      MYSQL_LINE_COMMENT = /--(?=[[:space:][:cntrl:]]|\z)[^\n]*/
      BLOCK_COMMENT = %r{/\*.*?(?:\*/|\z)}m
      NESTED_BLOCK_COMMENT = %r{(?<comment>/\*(?:[^/*]|/(?!\*)|\*(?!/)|\g<comment>)*(?:\*/|\z))}m
      BRACKET_QUOTED = /\[[^\]]*\]?/
      WORD = /[[:alpha:]_][[:alnum:]_$]*/
      STRING_CONTINUATION = /[ \t\f\r]*\n[[:space:]]*(?=')/
      DOLLAR_QUOTED = /\$([[:alpha:]_][[:alnum:]_]*|)\$.*?(?:\$\1\$|\z)/m

      def self.inject(query, context_variables, record_id, connection = ActiveRecord::Base.connection)
        new(context_variables, record_id, connection).inject(query)
      end

      def initialize(context_variables, record_id, connection)
        @context_variables = context_variables
        @record_id = record_id
        @connection = connection
        @mysql = connection.adapter_name.match?(/mysql|trilogy/i)
        @postgresql = connection.adapter_name.match?(/postg/i)
        @bracket_quotes = connection.adapter_name.match?(/sqlite|sqlserver/i)
        @nested_comments = @postgresql || connection.adapter_name.match?(/sqlserver/i)
        @backslash_escapes = @mysql && mysql_backslash_escapes?
      end

      def inject(query)
        scanner = StringScanner.new(query)
        injected = +''
        injected << next_token(scanner) until scanner.eos?
        injected
      end

      private

      def next_token(scanner)
        if (comment = scan_comment(scanner))
          comment
        elsif (word = scanner.scan(WORD))
          return word unless @postgresql && word.casecmp?('e') && scanner.peek(1) == "'"

          word + inject_in_string(scan_escape_string(scanner), backslash_escapes: true, escape_backslashes: true)
        elsif (string = scanner.scan(quoted_pattern("'", backslash_escapes: @backslash_escapes)))
          inject_in_string(string, backslash_escapes: @backslash_escapes, escape_backslashes: false)
        elsif (quoted = scan_quoted_text(scanner))
          inject_in_quoted_text(quoted)
        elsif (placeholder = scanner.scan(PLACEHOLDER))
          inject_in_code(placeholder)
        else
          scanner.getch
        end
      end

      def mysql_backslash_escapes?
        !@connection.select_value('SELECT @@SESSION.sql_mode').to_s.include?('NO_BACKSLASH_ESCAPES')
      end

      def scan_comment(scanner)
        scanner.scan(@mysql ? MYSQL_LINE_COMMENT : LINE_COMMENT) ||
          scanner.scan(@nested_comments ? NESTED_BLOCK_COMMENT : BLOCK_COMMENT) ||
          (@mysql && scanner.scan(/#[^\n]*/))
      end

      def scan_escape_string(scanner)
        escape_string = scanner.scan(quoted_pattern("'", backslash_escapes: true))
        while (continuation = scanner.scan(STRING_CONTINUATION))
          escape_string << continuation << scanner.scan(quoted_pattern("'", backslash_escapes: true))
        end
        escape_string
      end

      def scan_quoted_text(scanner)
        scanner.scan(quoted_pattern('"', backslash_escapes: @backslash_escapes)) ||
          scanner.scan(quoted_pattern('`')) ||
          (@postgresql && scanner.scan(DOLLAR_QUOTED)) ||
          (@bracket_quotes && scanner.scan(BRACKET_QUOTED))
      end

      def quoted_pattern(quote, backslash_escapes: false)
        escaped = Regexp.escape(quote)
        content = backslash_escapes ? "[^#{escaped}\\\\]|\\\\.|#{escaped}#{escaped}" : "[^#{escaped}]|#{escaped}#{escaped}"
        /#{escaped}(?:#{content})*#{escaped}?/m
      end

      def inject_in_code(placeholder)
        replace_placeholders(placeholder) do |text|
          text.match?(VERBATIM_VALUE) ? text : @connection.quote(text)
        end
      end

      def inject_in_string(string, backslash_escapes:, escape_backslashes:)
        replace_placeholders(string) do |text, placeholder, preceding_text|
          if backslash_escapes && preceding_text[/\\*\z/].length.odd?
            raise ForestLiana::Errors::LiveQueryError.new(
              "Live Query Chart: #{placeholder} cannot follow a backslash inside a string."
            )
          end
          escape_backslashes ? text.gsub(/[\\']/) { |character| character * 2 } : @connection.quote_string(text)
        end
      end

      def inject_in_quoted_text(quoted)
        replace_placeholders(quoted) do |text, placeholder|
          if text.match?(CHARACTERS_CLOSING_QUOTED_TEXT)
            raise ForestLiana::Errors::LiveQueryError.new(
              "Live Query Chart: The value of #{placeholder} cannot contain quotes, brackets, backslashes, " \
              'dollar signs or line breaks when it is written inside a quoted identifier or a dollar-quoted string.'
            )
          end
          text
        end
      end

      def replace_placeholders(text)
        text.gsub(PLACEHOLDER) do |placeholder|
          context_variable_key = Regexp.last_match(1)
          preceding_text = Regexp.last_match.pre_match
          if context_variable_key
            value = ContextVariablesInjector.context_value(context_variable_key, @context_variables)
            yield(value, placeholder, preceding_text)
          elsif @record_id.nil?
            placeholder
          else
            yield(@record_id.to_s, placeholder, preceding_text)
          end
        end
      end
    end
  end
end
