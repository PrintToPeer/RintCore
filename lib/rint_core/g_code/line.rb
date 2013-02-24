require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module GCode
    module Line

      attr_accessor :imperial, :relative, :f
      attr_writer :x, :y, :z, :e

      def initialize_line(line)
        @coordinates = ['X','Y','Z','E','F']
        @f = 0

        @number_pattern = /[-]?\d+[.]?\d*/

        @raw = line.upcase.strip
        @raw = @raw.split(RintCore::GCode::Codes.COMMENT_SYMBOL).first if line.include?(RintCore::GCode::Codes.COMMENT_SYMBOL)

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

      def command(line)
        if line.present?
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
        @raw.include?(RintCore::GCode::Codes.RAPID_MOVE) || @raw.include?(RintCore::GCode::Codes.CONTROLLED_MOVE)
      end

    end
  end
end