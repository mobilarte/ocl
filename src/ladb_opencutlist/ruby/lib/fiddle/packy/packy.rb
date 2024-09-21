require 'json'
require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Packy
    extend ClipperWrapper

    PROBLEM_TYPE_RECTANGLE = 'rectangle'
    PROBLEM_TYPE_RECTANGLEGUILLOTINE = 'rectangleguillotine'
    PROBLEM_TYPE_IRREGULAR = 'irregular'
    PROBLEM_TYPE_ONEDIMENSIONAL = 'onedimensional'

    @@cache = {}
    @@running_input_md5 = nil

    def self._lib_name
      'Packy'
    end

    def self._lib_c_functions
      [

        'char* c_optimize_start(char*)',
        'char* c_optimize_advance()',
        'void c_optimize_cancel()',

        'char* c_version()',

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.optimize_start(input, no_cache = false)
      _load_lib
      input_json = input.to_json
      input_md5 = Digest::MD5.hexdigest(input_json)
      if !no_cache && @@cache.key?(input_md5)
        return @@cache[input_md5]
      end
      @@running_input_md5 = input_md5
      JSON.parse(c_optimize_start(input_json).to_s)
    end

    def self.optimize_advance
      _load_lib
      output = JSON.parse(c_optimize_advance.to_s)
      if !@@running_input_md5.nil? && !output['running'] && !output['cancelled']
        @@cache[@@running_input_md5] = output
        @@running_input_md5 = nil
      end
      output
    end

    def self.optimize_cancel
      c_optimize_cancel if loaded?
    end

    # -----

    BinDef = Struct.new(:length, :width, :type)
    ItemDef = Struct.new(:projection_def, :data, :color)

    Bin = Struct.new(:def, :copies, :items, :cuts)
    Item = Struct.new(:def, :x, :y, :angle, :mirror)
    Cut = Struct.new(:depth, :x, :y, :length, :orientation)

  end

end
