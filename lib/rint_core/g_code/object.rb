require 'rint_core/g_code/codes'
require 'rint_core/g_code/line'
require 'active_support/core_ext/object/blank'

module RintCore
  module GCode
    class Object
      include RintCore::GCode::Codes

      attr_accessor :raw_data
      attr_reader :lines, :x_min, :x_max, :y_min, :y_max, :z_min, :z_max,
                  :filament_used, :x_travel, :y_travel, :z_travel, :e_travel,
                  :width, :depth, :height

      def initialize(data = nil)
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
      end

private

      def process
        set_variables

        @lines.each do |line|
          if line.command == USE_INCHES
            @imperial = true
          elsif line.command == USE_MILLIMETRES
            @imperial = false
          elsif line.command == ABS_POSITIONING
            @relative = false
          elsif line.command == REL_POSITIONING
            @relative = true
          elsif line.command == SET_POSITION
            @current_x = line.x if line.x.present?
            @current_y = line.y if line.y.present?
            @current_z = line.z if line.z.present?
            if line.e.present?
              @filament_used += @current_e
              @current_e = line.e
            end
          elsif line.command == HOME
            home_axes(line)
          elsif line.is_move?
            line.imperial = @imperial
            line.relative = @relative
            measure_travel(line)
            set_current_position(line)
            set_limits(line)
          end
        end

        @width = x_max - x_min
        @depth = y_max - y_min
        @height = z_max - z_min
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
      end

    end
  end
end