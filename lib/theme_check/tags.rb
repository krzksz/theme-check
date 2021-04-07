# frozen_string_literal: true

module ThemeCheck
  module Tags
    # Copied tags parsing code from storefront-renderer

    class Section < Liquid::Tag
      SYNTAX = /\A\s*(?<section_name>#{Liquid::QuotedString})\s*\z/o

      attr_reader :section_name

      def initialize(tag_name, markup, options)
        super

        match = markup.match(SYNTAX)
        raise(
          Liquid::SyntaxError,
          "Error in tag 'section' - Valid syntax: section '[type]'",
        ) unless match
        @section_name = match[:section_name].tr(%('"), '')
        @section_name.chomp!(".liquid") if @section_name.end_with?(".liquid")
      end
    end

    class Form < Liquid::Block
      TAG_ATTRIBUTES = /([\w\-]+)\s*:\s*(#{Liquid::QuotedFragment})/o
      # Matches forms with arguments:
      #  'type', object
      #  'type', object, key: value, ...
      #  'type', key: value, ...
      #
      # old format: form product
      # new format: form "product", product, id: "newID", class: "custom-class", data-example: "100"
      FORM_FORMAT = %r{
        (?<type>#{Liquid::QuotedFragment})
        (?:\s*,\s*(?<variable_name>#{Liquid::VariableSignature}+)(?!:))?
        (?<attributes>(?:\s*,\s*(?:#{TAG_ATTRIBUTES}))*)\s*\Z
      }xo

      attr_reader :type_expr, :variable_name_expr, :tag_attributes

      def initialize(tag_name, markup, options)
        super
        @match = FORM_FORMAT.match(markup)
        raise Liquid::SyntaxError, "in 'form' - Valid syntax: form 'type'[, object]" unless @match
        @type_expr = parse_expression(@match[:type])
        @variable_name_expr = parse_expression(@match[:variable_name])
        tag_attributes = @match[:attributes].scan(TAG_ATTRIBUTES)
        tag_attributes.each do |kv_pair|
          kv_pair[1] = parse_expression(kv_pair[1])
        end
        @tag_attributes = tag_attributes
      end

      class ParseTreeVisitor < Liquid::ParseTreeVisitor
        def children
          super + [@node.type_expr, @node.variable_name_expr] + @node.tag_attributes
        end
      end
    end

    class Paginate < Liquid::Block
      SYNTAX = /(?<liquid_variable_name>#{Liquid::QuotedFragment})\s*((?<by>by)\s*(?<page_size>#{Liquid::QuotedFragment}))?/

      attr_reader :page_size

      def initialize(tag_name, markup, options)
        super

        if (matches = markup.match(SYNTAX))
          @liquid_variable_name = matches[:liquid_variable_name]
          @page_size = parse_expression(matches[:page_size])
          @window_size = nil # determines how many pagination links are shown

          @liquid_variable_count_expr = parse_expression("#{@liquid_variable_name}_count")

          var_parts = @liquid_variable_name.rpartition('.')
          @source_drop_expr = parse_expression(var_parts[0].empty? ? var_parts.last : var_parts.first)
          @method_name = var_parts.last.to_sym

          markup.scan(Liquid::TagAttributes) do |key, value|
            case key
            when 'window_size'
              @window_size = value.to_i
            end
          end
        else
          raise(Liquid::SyntaxError, "in tag 'paginate' - Valid syntax: paginate [collection] by number")
        end
      end

      class ParseTreeVisitor < Liquid::ParseTreeVisitor
        def children
          super + [@node.page_size]
        end
      end
    end

    class Layout < Liquid::Tag
      SYNTAX = /(?<layout>#{Liquid::QuotedFragment})/

      NO_LAYOUT_KEYS = %w(false nil none).freeze

      attr_reader :layout_expr

      def initialize(tag_name, markup, tokens)
        super
        match = markup.match(SYNTAX)
        raise(
          Liquid::SyntaxError,
          "in 'layout' - Valid syntax: layout (none|[layout_name])",
        ) unless match
        layout_markup = match[:layout]
        @layout_expr = if NO_LAYOUT_KEYS.include?(layout_markup.downcase)
          false
        else
          parse_expression(layout_markup)
        end
      end

      class ParseTreeVisitor < Liquid::ParseTreeVisitor
        def children
          [@node.layout_expr]
        end
      end
    end

    class Style < Liquid::Block; end

    class Schema < Liquid::Raw; end

    class Javascript < Liquid::Raw; end

    class Stylesheet < Liquid::Raw; end

    Liquid::Template.register_tag('form', Form)
    Liquid::Template.register_tag('layout', Layout)
    Liquid::Template.register_tag('paginate', Paginate)
    Liquid::Template.register_tag('section', Section)
    Liquid::Template.register_tag('style', Style)
    Liquid::Template.register_tag('schema', Schema)
    Liquid::Template.register_tag('javascript', Javascript)
    Liquid::Template.register_tag('stylesheet', Stylesheet)
  end
end
