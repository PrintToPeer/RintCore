module RintCore
  module GCode
    module Codes
      RAPID_MOVE      = 'G0'
      CONTROLLED_MOVE = 'G1'
      DWELL           = 'G4'
      HEAD_OFFSET     = 'G10'
      USE_INCHES      = 'G20'
      USE_MILLIMETRES  = 'G21'
      HOME            = 'G28'
      ABS_POSITIONING = 'G90'
      REL_POSITIONING = 'G91'
      SET_POSITION    = 'G92'
      STOP            = 'M0'
      SLEEP           = 'M1'
      ENABLE_MOTORS   = 'M17'
      DISABLE_MOTORS  = 'M18'
      LIST_SD         = 'M20'
      INIT_SD         = 'M21'
      RELEASE_SD      = 'M22'
      SELECT_SD_FILE  = 'M23'
      START_SD_PRINT  = 'M24'
      PAUSE_SD_PRINT  = 'M25'
      SET_SD_POSITION = 'M26'
      SD_PRINT_STATUS = 'M27'
      START_SD_WRITE  = 'M28'
      STOP_SD_WRITE   = 'M29'
      POWER_ON        = 'M80'
      POWER_OFF       = 'M81'
      ABS_EXT_MODE    = 'M82'
      REL_EXT_MODE    = 'M83'
      IDLE_HOLD_OFF   = 'M84'
      SET_EXT_TEMP_NW = 'M104'
      GET_EXT_TEMP    = 'M105'
      FAN_ON          = 'M106'
      FAN_OFF         = 'M107'
      SET_EXT_TEMP_W  = 'M109'
      SET_LINE_NUM    = 'M110'
      EMRG_STOP       = 'M112'
      GET_POSITION    = 'M114'
      GET_FW_DETAILS  = 'M115'
      WIAT_FOR_TEMP   = 'M116'
      # ... Left out codes that probably won't be used
      SET_BED_TEMP_NW = 'M140'
      SET_BED_TEMP_W  = 'M190'
      COMMENT_SYMBOL  = ';'
    end
  end
end