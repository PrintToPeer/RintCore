require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module GCode
    # Represents a single line in a GCode file
    class Line
      include RintCore::GCode::Codes

      # @!macro attr_accessor
      #   @!attribute [rw] $1
      #     @param bool [Boolean] false if metric (default), true if imperial.
      #     @return [Boolean] false if metric (default), true if imperial.
      #   @!attribute [rw] $2
      #     @param bool [Boolean] false if absolute (default), true if realtive.
      #     @return [Boolean] false if absolute (default), true if relative.
      #   @!attribute [rw] $3
      #     @param multiplier [Float] number speed (F) will be multiplied by.
      #     @return [nil] if the speed multiplier is not set.
      #     @return [Float] the speed multiplier.
      #   @!attribute [rw] $4
      #   @param multiplier [Float] number extrusions (E) will be multiplied by.
      #   @return [nil] if the extrusion multiplier is not set.
      #   @return [Float] the extrusion multiplier.
      attr_accessor :imperial, :relative, :speed_multiplier, :extrusion_multiplier

      # @!macro attr_reader
      #   @!attribute [r] $1
      #     @return [String] the line, stripped of comments.
      attr_reader :raw

      # Creates a {Line}
      # @param line [String] a line of GCode.
      # @param strict [Boolean] return false if GCode doesn't start with a proper command.
      # @return [false] if GCode doesn't start with a proper command.
      # @return [Line]
      def initialize(line, strict = false)
        return false unless line.present?
        @coordinates = ['X','Y','Z','E','F']
        @number_pattern = /[-]?\d+[.]?\d*/
        @raw = line.upcase.strip
        @raw = @raw.split(COMMENT_SYMBOL).first.strip if line.include?(COMMENT_SYMBOL)
        return false unless !strict && @raw.start_with?(*available_commands)
        parse_coordinates
      end

      # @param multiplier [Float] number extrusions (E) will be multiplied by.
      # @return [Float] the extrusion multiplier.
      # def extrusion_multiplier=(multiplier)
      #   @extrusion_multiplier = check_multiplier(multiplier)
      # end


      # @param multiplier [Float] number speed (F) will be multiplied by.
      # @return [Float] the speed multiplier.
      # def speed_multiplier=(multiplier)
      #   @speed_multiplier = check_multiplier(multiplier)
      #   return @speed_multiplier
      # end

      # The X coordinate of the line.
      # @return [nil] if X not in line.
      # @return [Float] if X is in line.
      def x
        to_mm @x
      end


      # The Y coordinate of the line.
      # @return [nil] if Y not in line.
      # @return [Float] if Y is in line.
      def y
        to_mm @y
      end

      # The Z coordinate of the line.
      # @return [nil] if Z not in line.
      # @return [Float] if Z is in line.
      def z
        to_mm @z
      end

      # The E coordinate of the line.
      # @return [nil] if E not in line.
      # @return [Float] if E is in line.
      def e
        to_mm @e
      end

      # The command in the line.
      # @return [String] a GCode command or a blank string if one isn't present.
      def command
        if @raw.present?
          @raw.split(' ').first
        else
          ''
        end
      end

      # Checks if the command in the line causes movement.
      # @return [Boolean] true if command moves printer, false otherwise.
      def is_move?
        @raw.start_with?(RAPID_MOVE) || @raw.start_with?(CONTROLLED_MOVE)
      end

      # Checks whether the line is a travel move or not.
      # @return [Boolean] true if line is a travel move, false otherwise.
      def travel_move?
        is_move? && !@e.present?
      end

      # Checks whether the line is as extrusion move or not.
      # @return [Boolean] true if line is an extrusion move, false otherwise.
      def extrusion_move?
        is_move? && @e.present? && @e > 0
      end

      # Checks wether the line is a full home or not.
      # @return [Boolean] true if line is full home, false otherwise.
      def full_home?
        command == HOME && @x.blank? && @y.blank? && @z.blank?
      end

      # Returns the line, modified if multipliers are set.
      # @return [String] the line.
      def to_s
        return @raw unless @extrusion_multiplier.present? || @speed_multiplier.present?

        new_f = @f.present? && valid_multiplier?(@speed_multiplier) ? @f * @speed_multiplier : @f
        new_e = @e.present? && valid_multiplier?(@extrusion_multiplier) ? @e * @extrusion_multiplier : @e

        x_string = @x.present? ? " X#{@x}" : ''
        y_string = @y.present? ? " Y#{@y}" : ''
        z_string = @z.present? ? " Z#{@z}" : ''
        e_string = @e.present? ? " E#{new_e}" : ''
        f_string = @f.present? ? " F#{new_f}" : ''

        "#{command}#{x_string}#{y_string}#{z_string}#{f_string}#{e_string}"
      end

private

      def get_float(axis)
        @raw.split(axis).last.scan(@number_pattern).first.to_f
      end

      def parse_coordinates
        @coordinates.each do |axis|
          send(axis.downcase+'=', get_float(axis)) if @raw.include?(axis)
        end
      end

      def valid_multiplier?(multiplier)
        multiplier.present? && (multiplier.class == Fixnum || multiplier.class == Float) && multiplier > 0
      end

      def x=(x)
        @x = x
      end

      def y=(y)
        @y = y
      end

      def z=(z)
        @z = z
      end

      def e=(e)
        @e = e
      end

      def f=(f)
        @f = f
      end

      def to_mm(number)
        number *= 25.4 if number.present? && @imperial
        number
      end

    end
  end
end