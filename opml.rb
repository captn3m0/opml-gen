# frozen_string_literal: true

require 'nokogiri'

class OPML
  PROPERTIES = %w[title date_created date_modified
                  owner_name owner_email docs].freeze

  attr_accessor :title, :date_created, :date_modified, :owner_name, :owner_email, :docs

  def initialize(&block)
    instance_eval(&block)
    @docs = 'http://dev.opml.org/spec2.html'
    @outlines = []
  end

  def camel_case(str)
    str.downcase.split('_').each_with_index.map do |v, i|
      i.zero? ? v : v.capitalize
    end.join
  end

  def add_outline(params)
    params = Hash[params.map { |k, v| [camel_case(k.to_s), v] }]
    @outlines.push params
  end

  def add_note_with_params(xml, attrs)
    attrs.each do |attr|
      val = send(attr.to_sym)
      key = camel_case(attr).to_sym
      xml.send(key, val) if val
    end
  end

  def xml(text)
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.opml(version: '2.0') do
        xml.head do
          add_note_with_params xml, PROPERTIES
        end

        xml.body do
          xml.outline text: text do
            @outlines.each do |outline|
              xml.outline outline
            end
          end
        end
      end
    end.to_xml
  end
end
