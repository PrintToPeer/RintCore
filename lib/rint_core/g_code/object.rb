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
        preprocess
        measure
        calculate_filament_usage
      end

private

      def preprocess
        @lines.each do |line|
          if line.command == USE_INCHES
            @imperial = true
          elsif line.command == USE_MILLIMETRES
            @imperial = false
          elsif line.command == ABS_POSITIONING
            @relative = false
          elsif line.command == REL_POSITIONING
            @relative = true
          elsif line.is_move?
            line.imperial = @imperial
            line.relative = @relative
          end
        end
      end

      def measure
        x_min = 999999999
        y_min = 999999999
        z_min = 0
        x_max = -999999999
        y_max = -999999999
        z_max = -999999999

        current_x = 0
        current_y = 0
        current_z = 0

        @x_travel = 0
        @y_travel = 0
        @z_travel = 0

        @lines.each do |line|
          if line.command == SET_POSITION
            current_x = line.x if line.x.present?
            current_y = line.y if line.y.present?
            current_z = line.z if line.z.present?
          elsif line.command == HOME
            if line.x.present? || line.full_home?
              @x_travel += current_x
              current_x = 0
            end
            if line.y.present? || line.full_home?
              @y_travel += current_y
              current_y = 0
            end
            if line.z.present? || line.full_home?
              @z_travel += current_z
              current_z = 0
            end
          elsif line.is_move?
            x = line.x
            y = line.y
            z = line.z
            
            if line.relative
              @x_travel += x.abs if x.present?
              @y_travel += y.abs if y.present?
              @z_travel += z.abs if z.present?
              x.present? ? x = current_x + x : x = current_x
              y.present? ? y = current_y + y : y = current_y
              z.present? ? z = current_z + z : z = current_z
            else
              @x_travel += (current_x - x).abs if x.present?
              @y_travel += (current_y - y).abs if y.present?
              @z_travel += (current_z - z).abs if z.present?
            end

            if x.present? && !x.zero? && line.extrusion_move?
              x_min = x if x < x_min
              x_max = x if x > x_max
            end

            if y.present? && !y.zero? && line.extrusion_move?
              y_min = y if y < y_min
              y_max = y if y > y_max
            end

            if z.present?
              z_min = z if z < z_min
              z_max = z if z > z_max
            end

            current_x = (x > current_x ? x : current_x) if x.present?
            current_y = (y > current_y ? y : current_y) if y.present?
            current_z = (z > current_z ? z : current_z) if z.present?
          end
        end

        @x_min = x_min
        @x_max = x_max
        @y_min = y_min
        @y_max = y_max
        @z_min = z_min
        @z_max = z_max

        @width = x_max - x_min
        @depth = y_max - y_min
        @height = z_max - z_min
      end

      def calculate_filament_usage
        return @filament_used if @filament_used.present?
        current_e = 0
        total_e = 0
        @lines.each do |line|
          if line.command == SET_POSITION
            unless line.e.nil?
              total_e += current_e
              current_e = line.e
            end
          elsif line.is_move? && !line.travel_move?
            line.relative ? current_e += line.e : current_e = line.e
          end
        end

        @filament_used = total_e
      end

    end
  end
end