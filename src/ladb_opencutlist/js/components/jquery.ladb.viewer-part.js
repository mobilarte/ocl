+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbViewerPart = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.$iframe = $('iframe', this.$element);

        this.$btnIsometricView = $('#ladb_viewer_part_btn_isometric_view', this.$element);
        this.$btnTopView = $('#ladb_viewer_part_btn_top_view', this.$element);
        this.$btnBottomView = $('#ladb_viewer_part_btn_bottom_view', this.$element);
        this.$btnFrontView = $('#ladb_viewer_part_btn_front_view', this.$element);
        this.$btnBackView = $('#ladb_viewer_part_btn_back_view', this.$element);
        this.$btnLeftView = $('#ladb_viewer_part_btn_left_view', this.$element);
        this.$btnRightView = $('#ladb_viewer_part_btn_right_view', this.$element);
        this.$btnToggleBoxHelper = $('#ladb_viewer_part_btn_toggle_box_helper', this.$element);
        this.$btnToggleAxesHelper = $('#ladb_viewer_part_btn_toggle_axes_helper', this.$element);
        this.$btnToggleAutoRotate = $('#ladb_viewer_part_btn_toggle_auto_rotate', this.$element);

    };

    LadbViewerPart.DEFAULTS = {
        modelDef: null,
        partsColored: false,
        pinsHidden: false,
        pinsColored: false,
        pinsLength: 1,  /* PINS_LENGTH_SHORT */
        pinsDirection: 0,   /* PINS_DIRECTION_CENTER */
        showBoxHelper: false,
    };

    LadbViewerPart.prototype.callCommand = function (command, params) {
        this.$iframe.get(0).contentWindow.postMessage({
            command: command,
            params: params
        }, '*');
    };

    LadbViewerPart.prototype.bind = function () {
        var that = this;

        // Bind iframe
        this.$iframe
            .on('load', function () {

                that.callCommand(
                    'setup_model',
                    {
                        modelDef: that.options.modelDef,
                        partsColored: that.options.partsColored,
                        pinsHidden: that.options.pinsHidden,
                        pinsColored: that.options.pinsColored,
                        pinsLength: that.options.pinsLength,
                        pinsDirection: that.options.pinsDirection,
                        showBoxHelper: that.options.showBoxHelper
                    }
                )

            }).attr('src', 'viewer.html');

        // Bind buttons
        $('button[data-command]', this.$element).on('click', function () {
            this.blur();
            var command = $(this).data('command');
            var params = $(this).data('params');
            that.callCommand(command, params);
        });

    };

    LadbViewerPart.prototype.init = function () {
        this.bind();
        this.dialog.setupTooltips(this.$element);
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.viewerPart');
            var options = $.extend({}, LadbViewerPart.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.editorExport', (data = new LadbViewerPart(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(params);
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbViewerPart;

    $.fn.ladbViewerPart = Plugin;
    $.fn.ladbViewerPart.Constructor = LadbViewerPart;


    // NO CONFLICT
    // =================

    $.fn.ladbViewerPart.noConflict = function () {
        $.fn.ladbViewerPart = old;
        return this;
    }

}(jQuery);