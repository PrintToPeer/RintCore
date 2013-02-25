require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module GCode
    class Line
      include RintCore::GCode::Codes

      attr_accessor :imperial, :relative, :f
      attr_reader :raw
      attr_writer :x, :y, :z, :e

      def initialize(line)
        @coordinates = ['X','Y','Z','E','F']
        @number_pattern = /[-]?\d+[.]?\d*/
        @raw = line.upcase.strip
        @raw = @raw.split(COMMENT_SYMBOL).first.strip if line.include?(COMMENT_SYMBOL)

        parse_coordinates
      end

      def to_mm(number)
        number *= 25.4 if number.present? && @imperial
        number
      end

      def x
        to_mm @x
      end

      def y
        to_mm @y
      end

      def z
        to_mm @z
      end

      def e
        to_mm @e
      end

      def command
        if @raw.present?
          @raw.split(' ').first
        else
          ''
        end
      end

      def get_float(axis)
        @raw.split(axis).last.scan(@number_pattern).first.to_f
      end

      def parse_coordinates
        @coordinates.each do |axis|
          send(axis.downcase+'=', get_float(axis)) if @raw.include?(axis)
        end
      end

      def is_move?
        @raw.start_with?(RAPID_MOVE) || @raw.start_with?(CONTROLLED_MOVE)
      end

      def travel_move?
        is_move? && !@e.present?
      end

      def extrusion_move?
        is_move? && @e.present? && @e > 0
      end

      def full_home?
        command == HOME && @x.blank? && @y.blank? && @z.blank?
      end

      def to_s
        @raw
      end

    end
  end
end