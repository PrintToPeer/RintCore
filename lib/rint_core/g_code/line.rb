require 'rint_core/g_code/codes'

module RintCore
  module GCode
    # Represents a single line in a GCode file, parse expression tester: {http://rubular.com/r/5zf5Hr489i}
    class Line
      include RintCore::GCode::Codes

      # @!macro attr_accessor
      #   @!attribute [rw] $1
      #     @param multiplier [Float] number speed (F) will be multiplied by.
      #     @return [nil] if the speed multiplier is not set.
      #     @return [Float] the speed multiplier (print moves only).
      #   @!attribute [rw] $2
      #     @param multiplier [Float] number extrusions (E) will be multiplied by.
      #     @return [nil] if the extrusion multiplier is not set.
      #     @return [Float] the extrusion multiplier.
      #   @!attribute [rw] $3
      #     @param multiplier [Float] number travel move speeds (F) will be multiplied by.
      #     @return [nil] if the travel multiplier is not set.
      #     @return [Float] the travel multiplier.
      #   @!attribute [rw] $4
      #     @return [Fixnum] the tool used in the command.
      attr_accessor :speed_multiplier, :extrusion_multiplier,
                    :travel_multiplier, :tool_number

      # @!macro attr_reader
      #   @!attribute [r] $1
      #     @return [String] the line, upcased and stripped of whitespace.
      #   @!attribute [r] $2
      #     @return [nil] if the line wasn't valid GCode.
      #     @return [MatchData] the raw matches from the regular evaluation expression.
      #   @!attribute [r] $3
      #     @return [String] ready to send version of the original line (no multipliers, call {#to_s} to apply multipliers).
      #   @!attribute [r] $4
      #     @return [String] command portion of the line.
      #   @!attribute [r] $5
      #     @return [String] command letter of the line (G,M,T).
      #   @!attribute [r] $6
      #     @return [Fixnum] command number of the line (ex. 28 for "G28").
      #   @!attribute [r] $7
      #     @return [nil] if there's no S data for the command.
      #     @return [Fixnum] S data for the command.
      #   @!attribute [r] $8
      #     @return [nil] if there's no P data for the command.
      #     @return [Fixnum] P data for the command.
      #   @!attribute [r] $9
      #     @return [nil] if there's no X coordinate of the command.
      #     @return [Float] X coordinate of the command.
      #   @!attribute [r] $10
      #     @return [nil] if there's no Y coordinate of the command.
      #     @return [Float] Y coordinate of the command.
      #   @!attribute [r] $11
      #     @return [nil] if there's no Z coordinate of the command.
      #     @return [Float] Z coordinate of the command.
      #   @!attribute [r] $12
      #     @return [nil] if there's no F parameter of the command.
      #     @return [Float] F parameter of the command.
      #   @!attribute [r] $13
      #     @return [nil] if there's no E parameter of the command.
      #     @return [Float] E parameter of the command.
      attr_reader :raw, :matches, :line, :command, :command_letter, :command_number,
                  :s_data, :p_data, :x, :y, :z, :f, :e

      # Creates a {Line}
      # @param line [String] a line of GCode.
      # @return [false] if line is empty or doesn't match the evaluation expression.
      # @return [Line]
      def initialize(line)
        return false if line.nil? || line.empty?
        @raw = line.upcase.strip
        @gcode_pattern = /^(?<line>(?<command>((?<command_letter>[G|M|T])(?<command_number>\d{1,3}))) ?([S](?<s_data>\d*))? ?([P](?<p_data>\d*))? ?([X](?<x_data>[-]?\d+\.?\d*))? ?([Y](?<y_data>[-]?\d+\.?\d*))? ?([Z](?<z_data>[-]?\d+\.?\d*))? ?([F](?<f_data>\d+\.?\d*))? ?([E](?<e_data>[-]?\d+\.?\d*))?)? ?;?(?<comment>.*)$/
        @matches = @raw.match(@gcode_pattern)
        return false if @matches.nil?
        assign_values unless @matches.nil?
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
        return @line if @extrusion_multiplier.nil? && @speed_multiplier.nil?

        new_f = multiplied_speed unless @f.nil?
        new_e = multiplied_extrusion unless @e.nil?

        x_string = !@x.nil? ? " X#{@x}" : ''
        y_string = !@y.nil? ? " Y#{@y}" : ''
        z_string = !@z.nil? ? " Z#{@z}" : ''
        e_string = !@e.nil? ? " E#{new_e}" : ''
        f_string = !@f.nil? ? " F#{new_f}" : ''

        "#{@command}#{x_string}#{y_string}#{z_string}#{f_string}#{e_string}"
      end

private

      def assign_values
        command_assignments
        coordinate_assignments
        @s = @matches[:s_data].to_i unless @matches[:s_data].nil?
        @p = @matches[:p_data].to_i unless @matches[:p_data].nil?
        @comment = @matches[:comment].strip unless @matches[:comment].nil?
      end

      def command_assignments
        @command = @matches[:command]
        @command_letter = @matches[:command_letter]
        @command_number = @matches[:command_number].to_i unless @matches[:command_number].nil?
        @tool_number = @command_number unless @matches[:command_letter].nil?
      end

      def coordinate_assignments
        @x = @matches[:x_data].to_f unless @matches[:x_data].nil?
        @y = @matches[:y_data].to_f unless @matches[:y_data].nil?
        @z = @matches[:z_data].to_f unless @matches[:z_data].nil?
        @f = @matches[:f_data].to_f unless @matches[:f_data].nil?
        @e = @matches[:e_data].to_f unless @matches[:e_data].nil?
      end

      def multiplied_extrusion
        if valid_multiplier?(@extrusion_multiplier)
          return @e * @extrusion_multiplier
        else
          @e
        end
      end

      def multiplied_speed
        if travel_move? && valid_multiplier?(@travel_multiplier)
          return @f * @travel_multiplier
        elsif extrusion_move? && valid_multiplier?(@speed_multiplier)
          return @f * @speed_multiplier
        else
         return @f
        end
      end

      def valid_multiplier?(multiplier)
        !multiplier.nil? && (multiplier.class == Fixnum || multiplier.class == Float) && multiplier > 0
      end


    end
  end
end