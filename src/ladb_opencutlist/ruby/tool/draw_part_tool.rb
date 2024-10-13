module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'

  class DrawPartTool < Kuix::KuixTool

    COLOR_BRAND = Sketchup::Color.new(247, 127, 0).freeze
    COLOR_BRAND_DARK = Sketchup::Color.new(62, 59, 51).freeze
    COLOR_BRAND_LIGHT = Sketchup::Color.new(214, 212, 205).freeze

    CURSOR_PENCIL = 632
    CURSOR_PENCIL_RECTANGLE = 637
    CURSOR_PENCIL_PUSHPULL = 639

    def initialize
      super(false, false)

      @mouse_x = -1
      @mouse_y = -1

    end

    def get_unit(view = nil)
      return @unit unless @unit.nil?
      return 3 if view && Sketchup.active_model.nil?
      view = Sketchup.active_model.active_view if view.nil?
      if view.vpheight > 2000
        @unit = 8
      elsif view.vpheight > 1000
        @unit = 6
      elsif view.vpheight > 500
        @unit = 4
      else
        @unit = 3
      end
      @unit
    end

    def get_text_unit_factor
      case PLUGIN.language
      when 'ar'
        return 1.5
      else
        return 1.0
      end
    end

    def setup_entities(view)

      # 2D
      # --------

      @canvas.layout = Kuix::StaticLayout.new

      unit = get_unit(view)

      # -- TOP

      @top_panel = Kuix::Panel.new
      @top_panel.layout_data = Kuix::StaticLayoutData.new(0, 0, 1.0, -1)
      @top_panel.layout = Kuix::BorderLayout.new
      @canvas.append(@top_panel)

        # Actions panel

        actions_panel = Kuix::Panel.new
        actions_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        actions_panel.layout = Kuix::BorderLayout.new
        actions_panel.set_style_attribute(:background_color, COLOR_BRAND_DARK)
        @actions_panel = actions_panel
        @top_panel.append(actions_panel)

          actions_lbl = Kuix::Label.new
          actions_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
          actions_lbl.padding.set!(0, unit * 4, 0, unit * 4)
          actions_lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
          actions_lbl.text = "DESSINER"
          actions_lbl.text_size = unit * 3 * get_text_unit_factor
          actions_lbl.text_bold = true
          actions_panel.append(actions_lbl)

          actions_btns_panel = Kuix::Panel.new
          actions_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
          actions_btns_panel.layout = Kuix::InlineLayout.new(true, 0, Kuix::Anchor.new(Kuix::Anchor::CENTER))
          actions_panel.append(actions_btns_panel)

            actions_btn = Kuix::Button.new
            actions_btn.layout = Kuix::BorderLayout.new
            actions_btn.border.set!(0, unit / 4, 0, unit / 4)
            actions_btn.min_size.set_all!(unit * 10)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_DARK.blend(Kuix::COLOR_WHITE, 0.8))
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND, :selected)
            lbl = actions_btn.append_static_label("Rectangle", unit * 3 * get_text_unit_factor)
            lbl.padding.set!(0, unit * 4, 0, unit * 4)
            lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            lbl.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            lbl.set_style_attribute(:color, Kuix::COLOR_WHITE, :selected)
            actions_btns_panel.append(actions_btn)

          # Help Button

          help_btn = Kuix::Button.new
          help_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
          help_btn.layout = Kuix::GridLayout.new
          help_btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
          help_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
          lbl = help_btn.append_static_label(PLUGIN.get_i18n_string("default.help").upcase, unit * 3 * get_text_unit_factor)
          lbl.min_size.set!(unit * 15, 0)
          lbl.padding.set!(0, unit * 4, 0, unit * 4)
          lbl.set_style_attribute(:color, COLOR_BRAND_DARK)
          actions_panel.append(help_btn)

    end

    def onActivate(view)
      super

      @mouse_ip = Sketchup::InputPoint.new
      @snap_ip = Sketchup::InputPoint.new
      @picked_first_ip = Sketchup::InputPoint.new
      @picked_second_ip = Sketchup::InputPoint.new
      @picked_third_ip = Sketchup::InputPoint.new

      @locked_normal = nil

      @rectangle_centred = false
      @box_centred = false

      @direction = nil
      @normal = _get_active_z_axis

      _update_status_text

      set_root_cursor(CURSOR_PENCIL_RECTANGLE)

    end

    def onResume(view)
      super
      _update_status_text
    end

    def onCancel(reason, view)
      if _picked_second_point?
        @picked_second_ip.clear
        pop_to_root_cursor
      elsif _picked_first_point?
        @picked_first_ip.clear
      else
        _reset
      end
      _refresh
    end

    def onMouseMove(flags, x, y, view)
      return true if super

      @mouse_x = x
      @mouse_y = y

      @snap_ip.clear
      @mouse_ip.pick(view, x, y)

      SKETCHUP_CONSOLE.clear
      puts "---"
      puts "vertex = #{@mouse_ip.vertex}"
      puts "edge = #{@mouse_ip.edge}"
      puts "face = #{@mouse_ip.face}"
      puts "instance_path.length = #{@mouse_ip.instance_path.length}"
      puts "transformation.identity? = #{@mouse_ip.transformation.identity?}"
      puts "degrees_of_freedom = #{@mouse_ip.degrees_of_freedom}"
      puts "view.inference_locked? = #{view.inference_locked?}"
      puts "---"

      @space.remove_all

      if _picked_second_point?

        # Pick third point

        if @mouse_ip.degrees_of_freedom > 2 ||
          @mouse_ip.instance_path.length == 0 ||
          @mouse_ip.position.on_plane?([ @picked_second_ip.position, @normal ]) ||
          @mouse_ip.face && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(@normal) ||
          @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(@normal)

          picked_point, _ = Geom::closest_points([ @picked_second_ip.position, @normal ], view.pickray(x, y))
          @snap_ip = Sketchup::InputPoint.new(picked_point)
          @mouse_ip.copy!(@snap_ip) # Set display? to false

        else

          # Force picked point to be projected to second picked point normal line
          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_line([ @picked_second_ip.position, @normal ]))

        end

        if @rectangle_centred || @box_centred

          # Draw first picked point
          k_points = Kuix::Points.new
          k_points.add_point(@picked_first_ip.position)
          k_points.line_width = 1
          k_points.size = 20
          k_points.style = Kuix::POINT_STYLE_PLUS
          @space.append(k_points)

          # Draw line from first picked point to snap point
          k_line = Kuix::LineMotif.new
          k_line.start.copy!(@picked_first_ip.position)
          k_line.end.copy!(@snap_ip.position)
          k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          @space.append(k_line)

        end

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p1 = points[0].transform(ti)
        p2 = points[1].transform(ti)
        p3 = points[2].transform(ti)

        pe = Geom::Point3d.new(p2.x, p2.y, p3.z)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, pe)

        k_box = Kuix::BoxMotif.new
        k_box.bounds.origin.copy!(bounds.min)
        k_box.bounds.size.set!(bounds.width, bounds.height, bounds.depth)
        k_box.line_width = 1.5
        k_box.color = _get_normal_color
        k_box.transformation = t
        @space.append(k_box)

        Sketchup.vcb_value = bounds.depth

      elsif _picked_first_point?

        # Pick second point

        ground_plane = [ @picked_first_ip.position, _get_active_z_axis ]

        if @mouse_ip.vertex

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?(ground_plane)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_x_axis ])

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_y_axis ])

            @normal = _get_active_y_axis

          else

            # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
            #
            # k_points = Kuix::Points.new
            # k_points.add_points([ vertex_manipulator.point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
            # k_points.color = Kuix::COLOR_MAGENTA
            # @space.append(k_points)
            #
            # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
            #
            #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
            #
            #   k_mesh = Kuix::Mesh.new
            #   k_mesh.add_triangles(face_manipulator.triangles)
            #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            #   @space.append(k_mesh)
            #
            # end

          end

        elsif @mouse_ip.edge

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?(ground_plane)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_x_axis ])

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_y_axis ])

            @normal = _get_active_y_axis

          else

            t = @mouse_ip.transformation
            ps = @mouse_ip.edge.start.position.transform(t)
            pe = @mouse_ip.edge.end.position.transform(t)

            if !@picked_first_ip.position.on_line?([ ps, ps.vector_to(pe) ])

              plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_first_ip.position, ps, pe ]))

              @direction = ps.vector_to(pe)
              @normal = plane_manipulator.normal

            else

              # TODO handle this case

            end

            # edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

            # k_points = Kuix::Points.new
            # k_points.add_points([ @picked_first_ip.position, ps, pe ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
            # k_points.color = Kuix::COLOR_BLUE
            # @space.append(k_points)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(edge_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @space.append(k_segments)

          end

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          else

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            if @picked_first_ip.position.on_plane?(face_manipulator.plane)

              @normal = face_manipulator.normal

            else

              p1 = @picked_first_ip.position
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_PLUS
              # k_points.color = Kuix::COLOR_RED
              # @space.append(k_points)

              plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
              plane_manipulator = PlaneManipulator.new(plane)

              @direction = _get_active_z_axis
              @normal = plane_manipulator.normal

            end

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
            # @space.append(k_mesh)

          end

        else

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            if @mouse_ip.degrees_of_freedom > 2
              @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), locked_plane))
            else
              @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            end
            @normal = @locked_normal

          else

            if @mouse_ip.degrees_of_freedom > 2
              picked_point = Geom::intersect_line_plane(view.pickray(x, y), ground_plane)
              @mouse_ip = Sketchup::InputPoint.new(picked_point) unless picked_point.nil?
            end

            if !@mouse_ip.position.on_plane?(ground_plane)

              p1 = @picked_first_ip.position
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_CROSS
              # k_points.color = Kuix::COLOR_RED
              # @space.append(k_points)

              plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
              plane_manipulator = PlaneManipulator.new(plane)

              @direction = _get_active_z_axis
              @normal = plane_manipulator.normal

            else

              @direction = nil
              @normal = _get_active_z_axis

            end

          end

        end

        @snap_ip.copy!(@mouse_ip) unless @snap_ip.valid?

        t = _get_transformation
        ti = t.inverse

        if @rectangle_centred

          k_points = Kuix::Points.new
          k_points.add_point(@picked_first_ip.position)
          k_points.line_width = 1
          k_points.size = 20
          k_points.style = Kuix::POINT_STYLE_PLUS
          @space.append(k_points)

          k_line = Kuix::LineMotif.new
          k_line.start.copy!(@picked_first_ip.position)
          k_line.end.copy!(@snap_ip.position)
          k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          @space.append(k_line)

        end

        points = _get_picked_points
        p1 = points[0].transform(ti)
        p2 = points[1].transform(ti)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, p2)

        k_rectangle = Kuix::RectangleMotif.new
        k_rectangle.bounds.origin.copy!(bounds.min)
        k_rectangle.bounds.size.set!(bounds.width, bounds.height, 0)
        k_rectangle.line_width = @locked_normal ? 3 : 1.5
        k_rectangle.color = _get_normal_color
        k_rectangle.transformation = t
        @space.append(k_rectangle)

        Sketchup.vcb_value = "#{bounds.width};#{bounds.height}"

      else

        # Pick first point

        if @mouse_ip.vertex

          vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)

          # k_points = Kuix::Points.new
          # k_points.add_points([ vertex_manipulator.point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
          # k_points.color = Kuix::COLOR_MAGENTA
          # @space.append(k_points)

          # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
          #
          #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          #   @space.append(k_mesh)
          #
          # end

        elsif @mouse_ip.edge

          # edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)
          #
          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(edge_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @space.append(k_segments)

          if @mouse_ip.face && @mouse_ip.edge.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            @normal = face_manipulator.normal

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            # @space.append(k_mesh)

          end

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

          @normal = face_manipulator.normal

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(face_manipulator.triangles)
          # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
          # @space.append(k_mesh)

        elsif @locked_normal.nil?

          @direction = nil
          @normal = _get_active_z_axis

        end

        @snap_ip.copy!(@mouse_ip) unless @snap_ip.valid?

      end

      # k_points = Kuix::Points.new
      # k_points.add_points([ @snap_ip.position ])
      # k_points.size = 30
      # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
      # k_points.color = Kuix::COLOR_YELLOW
      # @space.append(k_points)

      # k_axes_helper = Kuix::AxesHelper.new
      # k_axes_helper.transformation = Geom::Transformation.axes(ORIGIN, *_get_axes)
      # @space.append(k_axes_helper)

      view.tooltip = @snap_ip.tooltip if @snap_ip.valid?
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      return true if super

      @mouse_x = x
      @mouse_y = y

      if !_picked_first_point?
        @picked_first_ip.copy!(@snap_ip)
        _refresh
      elsif !_picked_second_point?
        if _valid_rectangle?
          @picked_second_ip.copy!(@snap_ip)
          push_cursor(CURSOR_PENCIL_PUSHPULL)
          _refresh
        else
          UI.beep
        end
      elsif _valid_box?
        @picked_third_ip.copy!(@snap_ip)
        _create_entity
        _reset
      else
        UI.beep
      end

      _update_status_text
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_ALT
        @rectangle_centred = !@rectangle_centred if _picked_first_point? && !_picked_second_point?
        @box_centred = !@box_centred if _picked_second_point?
        _refresh
      end
      unless _picked_second_point?
        if key == VK_RIGHT
          x_axis = _get_active_x_axis
          if @locked_normal == x_axis
            @locked_normal = nil
          else
            @locked_normal = x_axis
          end
          _refresh
        elsif key == VK_LEFT
          y_axis = _get_active_y_axis
          if @locked_normal == y_axis
            @locked_normal = nil
          else
            @locked_normal = y_axis
          end
          _refresh
        elsif key == VK_UP
          z_axis = _get_active_z_axis
          if @locked_normal == z_axis
            @locked_normal = nil
          else
            @locked_normal = z_axis
          end
          _refresh
        elsif key == VK_DOWN
          if @locked_normal
            @locked_normal = nil
          else
            @locked_normal = @normal
          end
          _refresh
        end
      end
    end

    def onUserText(text, view)

      if _picked_second_point?

        thickness = text.to_l

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p2 = points[1].transform(ti)
        p3 = points[2].transform(ti)

        thickness *= -1 if p3.z < p2.z

        thickness = p3.z - p2.z if thickness == 0
        thickness /= 2 if @box_centred

        @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, thickness).transform(t))

        _create_entity
        _reset

        Sketchup.vcb_value = ''

      elsif _picked_first_point?

        d1, d2, d3 = text.split(';')

        if d1 || d2

          length = d1 ? d1.to_l : 0
          width = d2 ? d2.to_l : 0

          t = _get_transformation
          ti = t.inverse

          p1 = @picked_first_ip.position.transform(ti)
          p2 = @snap_ip.position.transform(ti)

          length *= -1 if p2.x < p1.x
          width *= -1 if p2.y < p1.y

          length = p2.x - p1.x if length == 0
          width = p2.y - p1.y if width == 0

          @picked_second_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p1.x + length, p1.y + width, p1.z).transform(t))

          push_cursor(CURSOR_PENCIL_PUSHPULL) unless d3

          Sketchup.vcb_value = ''

          _refresh

        end
        if d3

          thickness = d3.to_l

          t = _get_transformation
          ti = t.inverse

          p2 = @picked_second_ip.position.transform(ti)
          p3 = @picked_third_ip.position.transform(ti)

          thickness *= -1 if p3.z < p2.z

          thickness = p3.z - p2.z if thickness == 0

          @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

          _create_entity
          _reset

          Sketchup.vcb_value = ''

        end
      end

    end

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    def enableVCB?
      _picked_first_point?
    end

    def getExtents
      return super if _get_picked_points.empty?
      bounds = Geom::BoundingBox.new
      bounds.add(_get_picked_points)
      bounds
    end

    private

    def _get_active_x_axis
      X_AXIS.transform(_get_edit_transformation)
    end

    def _get_active_y_axis
      Y_AXIS.transform(_get_edit_transformation)
    end

    def _get_active_z_axis
      Z_AXIS.transform(_get_edit_transformation)
    end

    def _get_axes

      if @direction.nil? || !@direction.perpendicular?(@normal)
        x_axis, y_axis, z_axis = @normal.axes
      else
        x_axis = @direction
        z_axis = @normal
        y_axis = z_axis * x_axis
      end

      [ x_axis, y_axis, z_axis ]
    end

    def _get_edit_transformation
      return IDENTITY if Sketchup.active_model.nil? || Sketchup.active_model.edit_transform.nil?
      Sketchup.active_model.edit_transform
    end

    def _get_transformation
      Geom::Transformation.axes(@picked_first_ip.position, *_get_axes)
    end

    def _update_status_text
      if _picked_second_point?
        Sketchup.status_text = 'Select end point.'
      elsif _picked_first_point?
        Sketchup.status_text = 'Select second point.'
      else
        Sketchup.status_text = 'Select start point.'
      end
    end

    def _refresh
      onMouseMove(0, @mouse_x, @mouse_y, Sketchup.active_model.active_view)
    end

    def _reset
      @mouse_ip.clear
      @snap_ip.clear
      @picked_first_ip.clear
      @picked_second_ip.clear
      @picked_third_ip.clear
      @direction = nil
      @locked_normal = nil
      @normal = _get_active_z_axis
      @space.remove_all
      _update_status_text
      Sketchup.vcb_value = ''
      pop_to_root_cursor
    end

    def _picked_first_point?
      @picked_first_ip.valid?
    end

    def _picked_second_point?
      @picked_second_ip.valid?
    end

    def _picked_third_point?
      @picked_third_ip.valid?
    end

    def _valid_rectangle?

      points = _get_picked_points
      return false if points.length < 2

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      p2.x - p1.x != 0 && p2.y - p1.y != 0
    end

    def _valid_box?

      points = _get_picked_points
      return false if points.length < 3

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p3 = points[2].transform(ti)

      p3.x - p1.x != 0 && p3.y - p1.y != 0 && p3.z - p1.z != 0
    end

    def _get_picked_points
      points = []
      points << @picked_first_ip.position if _picked_first_point?
      points << @picked_second_ip.position if _picked_second_point?
      points << @picked_third_ip.position if _picked_third_point?
      points << @snap_ip.position if @snap_ip.valid?

      if @rectangle_centred && _picked_first_point? && points.length > 1
        points[0] = points[0].offset(points[1].vector_to(points[0]))
      end
      if @box_centred && _picked_second_point? && points.length > 2
        offset = points[2].vector_to(points[1])
        points[0] = points[0].offset(offset)
        points[1] = points[1].offset(offset)
      end

      points
    end

    def _get_normal_color
      return Kuix::COLOR_RED if @normal.parallel?(_get_active_x_axis)
      return Kuix::COLOR_GREEN if @normal.parallel?(_get_active_y_axis)
      return Kuix::COLOR_BLUE if @normal.parallel?(_get_active_z_axis)
      return Kuix::COLOR_MAGENTA if @normal == @locked_normal
      Kuix::COLOR_BLACK
    end

    def _create_entity

      model = Sketchup.active_model
      model.start_operation('Create Part', true)

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p3 = points[2].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p3)

      definition = model.definitions.add('Part')

      face = definition.entities.add_face([
                                       bounds.corner(0),
                                       bounds.corner(1),
                                       bounds.corner(3),
                                       bounds.corner(2)
                                     ])
      face.pushpull(p1.z >= 0 && p1.z < p3.z ? -bounds.depth : bounds.depth, bounds.corner(0).vector_to(bounds.corner(0)))
      face.reverse! if face.normal.samedirection?(Z_AXIS)

      model.active_entities.add_instance(definition, t)

      model.commit_operation

    end

  end

end