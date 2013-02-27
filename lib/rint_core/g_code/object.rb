require 'rint_core/g_code/codes'
require 'rint_core/g_code/line'
require 'active_support/core_ext/object/blank'

module RintCore
  module GCode
    # A class that represents a processed GCode file.
    class Object
      include RintCore::GCode::Codes

      # An array of the raw Gcode with each line as an element.
      # @return [Array] of raw GCode without the comments stripped out.
      attr_accessor :raw_data
      # @!macro attr_reader
      #   @!attribute [r] $1
      #     @return [Array<Line>] an array of {Line}s.
      #   @!attribute [r] $2
      #     @return [Float] the smallest X coordinate of an extrusion line.
      #   @!attribute [r] $3
      #     @return [Float] the biggest X coordinate of an extrusion line.
      #   @!attribute [r] $4
      #     @return [Float] the smallest Y coordinate of an extrusion line.
      #   @!attribute [r] $5
      #     @return [Float] the biggest Y coordinate of an extrusion line.
      #   @!attribute [r] $6
      #     @return [Float] the smallest Z coordinate.
      #   @!attribute [r] $7
      #     @return [Float] the biggest Z coordinate.
      #   @!attribute [r] $8
      #     @return [Float] the amount in mm of fliament extruded.
      #   @!attribute [r] $9
      #     @return [Float] the distance in total that the X axis will travel in mm.
      #   @!attribute [r] $10
      #     @return [Float] the distance in total that the Y axis will travel in mm.
      #   @!attribute [r] $11
      #     @return [Float] the distance in total that the Z axis will travel in mm.
      #   @!attribute [r] $12
      #     @return [Float] the distance in total that the E axis will travel in mm.
      #     @todo implement this
      #   @!attribute [r] $13
      #     @return [Float] the width of the print.
      #   @!attribute [r] $14
      #     @return [Float] the depth of the print.
      #   @!attribute [r] $15
      #     @return [Float] the height of the print.
      #   @!attribute [r] $16
      #   @return [Fixnum] the number of layers in the print.
      attr_reader :lines, :x_min, :x_max, :y_min, :y_max, :z_min, :z_max,
                  :filament_used, :x_travel, :y_travel, :z_travel, :e_travel,
                  :width, :depth, :height, :layers

      # Creates a GCode {Object}.
      # @param data [String] path to a GCode file on the system.
      # @param data [Array] with each element being a line of GCode.
      # @return [Object] if data is valid, returns a GCode {Object}.
      # @return [false] if data is not an array, path or didn't contain GCode.
      def initialize(data = nil)
        if data.class == String && self.class.is_file?(data)
          data = self.class.get_file(data)
        end
        return false if data.blank? || data.class != Array
        @raw_data = data
        @imperial = false
        @relative = false
        @lines = []
        data.each do |line|
          line = RintCore::GCode::Line.new(line)
          @lines << line if line.raw.present?
        end
        process
        present? ? self : false
      end

      # Checks if the given string is a file and if it exists.
      # @param file [String] path to a file on the system.
      # @return [Boolean] true if is a file that exists on the system, false otherwise.
      def self.is_file?(file)
        file.present? && File.exist?(file) && File.file?(file)
      end

      # Returns an array of the lines of the file if it exists.
      # @param file [String] path to a file on the system.
      # @return [Array] containting the lines of the given file as elements.
      # @return [false] if given string isn't a file or doesn't exist.
      def self.get_file(file)
        return false unless self.is_file?(file)
        IO.readlines(file)
      end

      # Checks if there are any {Line}s in {#lines}.
      # @return [Boolean] true if no lines, false otherwise.
      def blank?
        @lines.blank?
      end

      # Opposite of {#blank?}.
      # @see #blank?
      def present?
        @lines.present?
      end

private

      def process
        set_variables

        @lines.each do |line|
          case line.command
          when USE_INCHES
            @imperial = true
          when USE_MILLIMETRES
            @imperial = false
          when ABS_POSITIONING
            @relative = false
          when REL_POSITIONING
            @relative = true
          when SET_POSITION
            set_positions(line)
          when HOME
            home_axes(line)
          when RAPID_MOVE
            movement_line(line)
          when CONTROLLED_MOVE
            count_layers(line)
            movement_line(line)
          end
        end

        @width = @x_max - @x_min
        @depth = @y_max - @y_min
        @height = @z_max - @z_min
      end

      def count_layers(line)
        if line.z.present? && line.z > @current_z
          @layers += 1
        end
      end

      def movement_line(line)
        line.imperial = @imperial
        line.relative = @relative
        measure_travel(line)
        set_current_position(line)
        set_limits(line)
      end

      def measure_travel(line)
        if line.relative
          @x_travel += line.x.abs if line.x.present?
          @y_travel += line.y.abs if line.y.present?
          @z_travel += line.z.abs if line.z.present?
        else
          @x_travel += (@current_x - line.x).abs if line.x.present?
          @y_travel += (@current_y - line.y).abs if line.y.present?
          @z_travel += (@current_z - line.z).abs if line.z.present?
        end
      end

      def home_axes(line)
        if line.x.present? || line.full_home?
          @x_travel += @current_x
          @current_x = 0
        end
        if line.y.present? || line.full_home?
          @y_travel += @current_y
          @current_y = 0
        end
        if line.z.present? || line.full_home?
          @z_travel += @current_z
          @current_z = 0
        end
      end

      def set_positions(line)
        @current_x = line.x if line.x.present?
        @current_y = line.y if line.y.present?
        @current_z = line.z if line.z.present?
        if line.e.present?
          @filament_used += @current_e
          @current_e = line.e
        end
      end

      def set_current_position(line)
        if line.relative
          @current_x += line.x if line.x.present?
          @current_y += line.y if line.y.present?
          @current_z += line.z if line.z.present?
          @current_e += line.e if line.e.present?
        else
          @current_x = line.x if line.x.present?
          @current_y = line.y if line.y.present?
          @current_z = line.z if line.z.present?
          @current_e = line.e if line.e.present?
        end
      end

      def set_limits(line)
        if line.extrusion_move?
          if line.x.present? && !line.x.zero?
            @x_min = @current_x if @current_x < @x_min
            @x_max = @current_x if @current_x > @x_max
          end
          if line.y.present? && !line.y.zero?
            @y_min = @current_y if @current_y < @y_min
            @y_max = @current_y if @current_y > @y_max
          end
        end
        if line.z.present?
          @z_min = @current_z if @current_z < @z_min
          @z_max = @current_z if @current_z > @z_max
        end
      end

      def set_variables
        @x_travel = 0
        @y_travel = 0
        @z_travel = 0
        @current_x = 0
        @current_y = 0
        @current_z = 0
        @current_e = 0
        @x_min = 999999999
        @y_min = 999999999
        @z_min = 0
        @x_max = -999999999
        @y_max = -999999999
        @z_max = -999999999
        @filament_used = 0
        @layers = 0
      end

    end
  end
end