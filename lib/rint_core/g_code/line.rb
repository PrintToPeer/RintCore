require 'rint_core/g_code/codes'

module RintCore
  module GCode
    # Represents a single line in a GCode file, parse expression tester: {http://rubular.com/r/5zf5Hr489i}
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
      #     @return [Float] the speed multiplier (print moves only).
      #   @!attribute [rw] $4
      #     @param multiplier [Float] number extrusions (E) will be multiplied by.
      #     @return [nil] if the extrusion multiplier is not set.
      #     @return [Float] the extrusion multiplier.
      #   @!attribute [rw] $5
      #     @param multiplier [Float] number travel move speeds (F) will be multiplied by.
      #     @return [nil] if the travel multiplier is not set.
      #     @return [Float] the travel multiplier.
      attr_accessor :imperial, :relative, :speed_multiplier, :extrusion_multiplier,
                    :travel_multiplier

      # @!macro attr_reader
      #   @!attribute [r] $1
      #     @return [String] the line, upcased and stripped of whitespace.
      #   @!attribute [r] $2
      #     @return [String] the line, stripped of comments.
      #   @!attribute [r] $3
      #     @return [nil] if the line wasn't valid GCode.
      #     @return [MatchData] the raw matches from the regular evaluation expression.
      #   @!attribute [r] $4
      #     @return [Regexp] the regular expression used to evaluate the line.
      attr_reader :raw, :command, :matches, :gcode_pattern

      # Creates a {Line}
      # @param line [String] a line of GCode.
      # @return [false] if line is empty or doesn't match the evaluation expression.
      # @return [Line]
      def initialize(line)
        return false if line.nil? || line.empty?
        @raw = line.upcase.strip
        @gcode_pattern = /^(?<line>(?<command>[G|M]\d{1,3}) ?([X](?<x_data>[-]?\d+\.?\d*))? ?([Y](?<y_data>[-]?\d+\.?\d*))? ?([Z](?<z_data>[-]?\d+\.?\d*))? ?([F](?<f_data>\d+\.?\d*))? ?([E](?<e_data>[-]?\d+\.?\d*))? ?([S](?<s_data>\d*))?)? ?;?(?<comment>.*)$/
        @matches = @raw.match(@gcode_pattern)
        return false if @matches.nil?
        assign_values unless @matches.nil?
      end

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

      # Checks if the command in the line causes movement.
      # @return [Boolean] true if command moves printer, false otherwise.
      def is_move?
        @command == RAPID_MOVE || @command == CONTROLLED_MOVE
      end

      # Checks whether the line is a travel move or not.
      # @return [Boolean] true if line is a travel move, false otherwise.
      def travel_move?
        is_move? && @e.nil?
      end

      # Checks whether the line is as extrusion move or not.
      # @return [Boolean] true if line is an extrusion move, false otherwise.
      def extrusion_move?
        is_move? && !@e.nil? && @e > 0
      end

      # Checks wether the line is a full home or not.
      # @return [Boolean] true if line is full home, false otherwise.
      def full_home?
        @command == HOME && !@x.nil? && !@y.nil? && !@z.nil?
      end

      # Returns the line, modified if multipliers are set.
      # @return [String] the line.
      def to_s
        return @raw if @extrusion_multiplier.nil? || @speed_multiplier.nil?

        unless @f.nil?
          if travel_move? && valid_multiplier?(@travel_multiplier)
            new_f = @f * @travel_multiplier
          elsif extrusion_move? && valid_multiplier?(@speed_multiplier)
            new_f = @f * @speed_multiplier
          else
            new_f = @f
          end
        end
        new_e = !@e.nil? && valid_multiplier?(@extrusion_multiplier) ? @e * @extrusion_multiplier : @e

        x_string = !@x.nil? ? " X#{@x}" : ''
        y_string = !@y.nil? ? " Y#{@y}" : ''
        z_string = !@z.nil? ? " Z#{@z}" : ''
        e_string = !@e.nil? ? " E#{new_e}" : ''
        f_string = !@f.nil? ? " F#{new_f}" : ''

        "#{@command}#{x_string}#{y_string}#{z_string}#{f_string}#{e_string}"
      end

private

      def assign_values
        @command = @matches[:command].strip unless @matches[:command].nil?
        @x = @matches[:x_data].to_f unless @matches[:x_data].nil?
        @y = @matches[:y_data].to_f unless @matches[:y_data].nil?
        @z = @matches[:z_data].to_f unless @matches[:z_data].nil?
        @f = @matches[:f_data].to_f unless @matches[:f_data].nil?
        @e = @matches[:e_data].to_f unless @matches[:e_data].nil?
        @s = @matches[:s_data].to_i unless @matches[:s_data].nil?
        @comment = @matches[:comment].strip unless @matches[:comment].nil?
      end

      def valid_multiplier?(multiplier)
        !multiplier.nil? && (multiplier.class == Fixnum || multiplier.class == Float) && multiplier > 0
      end

      def to_mm(number)
        return number unless @imperial
        number *= 25.4 if !number.nil?
      end

    end
  end
end