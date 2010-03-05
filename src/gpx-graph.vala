/* Gpx Viewer 
 * Copyright (C) 2009-2009 Qball Cow <qball@sarine.nl>
 * Project homepage: http://blog.sarine.nl/ 

 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

using Gtk;
using Gpx;
using GLib;
using Config;

static const string LOG_DOMAIN="GPX_PARSER";
static const string unique_graph = Config.VERSION;
namespace Gpx
{
	public class Graph: Gtk.EventBox
	{
		/* Public */
		/* Holds the track */
		public Gpx.Track track = null;
		public enum  GraphMode {
			SPEED,
			ELEVATION,
			DISTANCE,
            ACCELERATION_H,
            ACCELERATION_V,
			NUM_GRAPH_MODES
		}
        
		/* Privates */
		private string[] GraphModeName = {
			N_("Speed (km/h) vs Time (HH:MM)"),
			N_("Elevation (m) vs Time (HH:MM)"),
			N_("Distance (km) vs Time (HH:MM)"),
			N_("Horizontal acceleration (m/s) vs Time (HH:MM)"),
			N_("Vertical speed (m/s) vs Time (HH:MM)")
		};
		
		/* By default elevation is shown */
		private GraphMode mode = GraphMode.ELEVATION;
		
		/* By default no smoothing is applied */
		private int _smooth_factor = 1;

		/* By default points are shown on graph */
		private bool _show_points = true;
        
		private Pango.FontDescription fd = null; 
		private Cairo.Surface surf = null;
		private int LEFT_OFFSET = 60;
		private int BOTTOM_OFFSET = 30;
		private time_t highlight = 0;

		private weak Gpx.Point? draw_current = null;


		public void hide_info()
		{
			draw_current = null; 
			this.queue_draw();
		}
		public void show_info(Gpx.Point? cur_point)
		{
			this.draw_current = cur_point;
			this.queue_draw();
		}

		public void switch_mode(GraphMode mode)
		{
			this.mode= mode;
			this.surf = null;
			/* Force a redraw */
			this.queue_draw();
		}

		public void set_highlight (time_t highlight) {
			this.highlight = highlight;
			/* Force a redraw */
			this.queue_draw();
		}

		public int smooth_factor {
			get { return _smooth_factor;}
			set {
				_smooth_factor = value;
				/* Invalidate the previous plot, so it is redrawn */
				this.surf = null;
				/* Force a redraw */
				this.queue_draw();
			}
			//default = 4;
		}

		public bool show_points {
			get { return _show_points;}
			set {
				_show_points = value;
				/* Invalidate the previous plot, so it is redrawn */
				this.surf = null;
				/* Force a redraw */
				this.queue_draw();
			}
		}

		public Graph ()
		{
			/* Create and setup font description */
			this.fd = new Pango.FontDescription();
			fd.set_family("sans mono");
			/* make the event box paintable and give it an own window to paint on */
			this.app_paintable = true;
			this.visible_window = true;
			/* signals */
			this.size_allocate.connect(size_allocate_cb);
			this.button_press_event.connect(button_press_event_cb);
			this.motion_notify_event.connect(motion_notify_event_cb);
			this.button_release_event.connect(button_release_event_cb);
		}

		public void set_track(Gpx.Track? track)
		{
			this.highlight = 0;
			this.track =track;
			/* Invalidate the previous plot, so it is redrawn */
			this.surf = null;
			/* Force a redraw */
			this.queue_draw();
			this.start = null;
			this.stop = null;
			/* */
			if(this.track != null && this.track.points != null)
				selection_changed(this.track, this.track.points.first().data, this.track.points.last().data);
			else
				selection_changed(this.track, null, null);
		}

		signal void point_clicked(Gpx.Point point);

		signal void selection_changed(Gpx.Track? track, Gpx.Point? start, Gpx.Point? stop);
		/**
		 * Private functions
		 */
		private Gpx.Point? get_point_from_position(double x, double y)
		{

			if(this.track == null) return null;
			if(x > LEFT_OFFSET && x < (this.allocation.width-10))
			{
				double elapsed_time = track.get_total_time();
				time_t time = (time_t)((x-LEFT_OFFSET)/(this.allocation.width-10-LEFT_OFFSET)*elapsed_time);
				weak List<Point?> iter = this.track.points.first();
				/* calculated time is offset from start time,  get real time */
				time += iter.data.get_time();
				while(iter.next != null)
				{
					if(time < iter.next.data.get_time() && (time == iter.data.get_time() || 
								time > iter.data.get_time()))
					{
						return iter.data;
					}
					iter = iter.next;
				}
			}
			return null;
		}
		private bool button_press_event_cb(Gdk.EventButton event)
		{
			if(this.track == null) return false;
			Gpx.Point *point = this.get_point_from_position(event.x, event.y); 
			if(point != null) {
				if(event.button == 1){
					this.start = point; 
				}else{ 
					this.start = null;
					point_clicked(point);
				}
			}
			return false;
		}

		private bool motion_notify_event_cb(Gdk.EventMotion event)
		{
			if(this.track == null) return false;
			if(this.start == null) return false;

			Gpx.Point *point = this.get_point_from_position(event.x, event.y); 
			if(point != null)
			{
				this.stop = point; 
				/* queue redraw so the selection is updated */
				this.queue_draw();
				if(this.start != null && this.stop  != null)
				{
					if(start.get_time() != stop.get_time())
					{
						if(start.get_time() < stop.get_time()) {
							selection_changed(this.track, start, stop);
						} else {
							selection_changed(this.track, stop, start);
						}
						return false;
					}
				}
				selection_changed(this.track, this.track.points.first().data, this.track.points.last().data);
			}
			return false;
		}
		private bool button_release_event_cb(Gdk.EventButton event)
		{
			if(this.track == null) return false;
			Gpx.Point *point = this.get_point_from_position(event.x, event.y); 
			if(point != null)
			{
				if(event.button == 1)
					this.stop = point; 
				else this.stop = null;
				this.queue_draw();
				if(event.button == 1)
				{
					if(this.start != null && this.stop  != null)
					{
						if(start.get_time() != stop.get_time())
						{
							if(start.get_time() < stop.get_time()) {
								selection_changed(this.track, start, stop);
							} else {
								selection_changed(this.track, stop, start);
							}
							return false;
						}
					}
					selection_changed(this.track, this.track.points.first().data, this.track.points.last().data);
				}
			}
			return false;
		}
		private void size_allocate_cb(Gdk.Rectangle alloc)
		{
			/* Invalidate the previous plot, so it is redrawn */
			this.surf = null;
		}

		private Gpx.Point start = null;
		private Gpx.Point stop = null;
		override bool expose_event(Gdk.EventExpose event)
		{
			var ctx = Gdk.cairo_create(this.window);
			/* If no valid surface, render it */
			if(surf == null)
				update_surface(this);

			/* Draw the actual surface on the widget */
			ctx.set_source_surface(this.surf, 0, 0);
			Gdk.cairo_region(ctx, event.region);
			ctx.clip();
			ctx.paint();

			ctx.translate(LEFT_OFFSET,20);
			/* Draw selection, if available */
			if(start != null && stop != null)
			{
				if(start.get_time() != stop.get_time())
				{
					Gpx.Point f = this.track.points.first().data;
					double elapsed_time = track.get_total_time();
					double graph_width = this.allocation.width-LEFT_OFFSET-10;
					double graph_height = this.allocation.height-20-BOTTOM_OFFSET;

					ctx.set_source_rgba(0.3, 0.2, 0.3, 0.8);
					ctx.rectangle((start.get_time()-f.get_time())/elapsed_time*graph_width, 0, 
							(stop.get_time()-start.get_time())/elapsed_time*graph_width, graph_height);
					ctx.stroke_preserve();
					ctx.fill();
				}

			}
			if(highlight > 0 )
			{
				Gpx.Point f = this.track.points.first().data;
				double elapsed_time = track.get_total_time();
				double graph_width = this.allocation.width-LEFT_OFFSET-10;
				double graph_height = this.allocation.height-20-BOTTOM_OFFSET;

				double hl = (highlight-f.get_time())/elapsed_time*graph_width; 

				ctx.set_source_rgba(0.8, 0.2, 0.3, 0.8);
				ctx.move_to(hl, 0);
				ctx.line_to(hl,graph_height);

				ctx.stroke_preserve();
				ctx.fill();
				/* Draw the speed/elavation/distance 
				 * in the upper top corner 
				 */
				if(this.draw_current != null)
				{
					var layout = Pango.cairo_create_layout(ctx);
					int w,h;
					var text = "";
					var x_pos =0.0;

					if(this.mode == GraphMode.SPEED) {
						text = "%.1f km/h".printf(this.draw_current.speed);
					}else if (this.mode == GraphMode.ELEVATION) {
						text = "%.1f m".printf(this.draw_current.elevation);
					}else if (this.mode == GraphMode.DISTANCE) {
						text = "%.1f km".printf(this.draw_current.distance);
					}

					fd.set_absolute_size(12*1024);
					layout.set_font_description(fd);
					layout.set_text(text,-1);
					layout.get_pixel_size(out w, out h);


					x_pos = (hl-(w+8)/2.0);
					if(x_pos < -LEFT_OFFSET) x_pos = 0.0;
					else if(hl+(w+8)/2.0 >= graph_width) x_pos = (double)graph_width - (double)(w+8.0);

					ctx.rectangle(x_pos, -h-2, w+8, h+4);
					ctx.set_source_rgba(0.0, 0.0, 0.0, 1.0);
					ctx.stroke_preserve();
					ctx.set_source_rgba(0.8, 0.8, 0.8, 0.8);
					ctx.fill();

					ctx.move_to(x_pos+4,-h);


					Pango.cairo_layout_path(ctx, layout);

					ctx.set_source_rgba(1.0, 1.0, 1.0, 1.0);
					ctx.stroke_preserve();
					ctx.set_source_rgba(0.0, 0.0, 0.0, 1.0);
					ctx.fill();
				}
			}
			return false;
		}
		private void update_surface(Gtk.Widget win)
		{
			var ctx = Gdk.cairo_create(win.window);
			this.surf = new Cairo.Surface.similar(ctx.get_target(),
					Cairo.Content.COLOR_ALPHA,
					win.allocation.width, win.allocation.height); 
			ctx = new Cairo.Context(this.surf);

			log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Updating surface");
			/* Paint background white */
			ctx.set_source_rgba(1,1,1,1);
			ctx.paint();
			if(this.track == null) return;
			double max_value = 0;
			double min_value = 0;
			double range = 0;
			if(this.mode == GraphMode.SPEED)
			{
				if(this.smooth_factor != 1)
				{
					weak List<Point?> iter = this.track.points.first();
					while(iter.next != null)
					{
						weak List<Point?> ii = iter.next;
						double speed = 0;
						int i=0;
						int sf = this.smooth_factor;
						for(i=0;i<sf && ii.prev != null; i++)
						{
							speed += track.calculate_point_to_point_speed(ii.prev.data, ii.data);
							ii = ii.prev;
						}
						speed = speed/i;
						max_value = (speed > max_value )?speed:max_value;
						iter = iter.next;
					}
				}
				else 
					max_value = track.max_speed;
			}else if (this.mode == GraphMode.ELEVATION){
				max_value = track.max_elevation;
				min_value = track.min_elevation;
			}else if (this.mode == GraphMode.DISTANCE){
				max_value = track.total_distance;
				min_value = 0;
            }else if (this.mode == GraphMode.ACCELERATION_H) {
                weak List<Point?> iter = this.track.points.first();
                while(iter.next != null)
                {
                    weak List<Point?> ii = iter.next;
                    double speed = 0;
                    int i=0;
                    int sf = this.smooth_factor;
                    for(i=0;i<sf && ii.prev != null; i++)
                    {
                        speed += (ii.data.speed- ii.prev.data.speed)/(3.6*(ii.data.get_time()-ii.prev.data.get_time()));
                        ii = ii.prev;
                    }
                    speed = speed/i;
                    max_value = (speed > max_value )?speed:max_value;
                    min_value = (speed < min_value)?speed:min_value;
                    iter = iter.next;
                }
            }else if (this.mode == GraphMode.ACCELERATION_V) {
                weak List<Point?> iter = this.track.points.first();
                while(iter.next != null)
                {
                    weak List<Point?> ii = iter.next;
                    double speed = 0;
                    int i=0;
                    int sf = this.smooth_factor;
                    for(i=0;i<sf && ii.prev != null; i++)
                    {
                        speed += (ii.data.elevation- ii.prev.data.elevation)/(3.6*(ii.data.get_time()-ii.prev.data.get_time()));
                        ii = ii.prev;
                    }
                    speed = speed/i;
                    max_value = (speed > max_value )?speed:max_value;
                    min_value = (speed < min_value)?speed:min_value;
                    iter = iter.next;
                }
            }
			range = max_value-min_value;
			double elapsed_time = track.get_total_time();


			log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Max speed: %f, elapsed_time: %f",
					max_value,
					elapsed_time);

			ctx.translate(LEFT_OFFSET,20);
			Point f = track.points.data;

			/* Draw Grid */
			double graph_width = win.allocation.width-LEFT_OFFSET-10;
			double graph_height = win.allocation.height-20-BOTTOM_OFFSET;

			var layout = Pango.cairo_create_layout(ctx);
			double j =0.0;
			double step_size = (graph_height)/8.0;
			ctx.set_source_rgba(0.2, 0.2, 0.2, 0.6);
			ctx.set_line_width(1);
			for(j=graph_height;j>0.0;j-=step_size){
				ctx.move_to(0.0,j);
				ctx.line_to(graph_width,j);
				ctx.stroke();
			}
			log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Draw grid lines");
			/* Draw speed and ticks */
			ctx.set_source_rgba(0.0, 0.0, 0.0, 1.0);
			double size = LEFT_OFFSET/("%.1f".printf(max_value).length);
			if(size > step_size) size = step_size;
			fd.set_absolute_size(size*1024);
			layout.set_font_description(fd);
			for(j=0;j<graph_height;j+=step_size){
				double speed = min_value + (range)*((graph_height-j)/graph_height);
				var text = "%.1f".printf(speed);
				int w,h;
				layout.set_text(text,-1);
				layout.get_pixel_size(out w, out h);
				ctx.move_to(-w-5, j-h/2.0);
				Pango.cairo_layout_path(ctx, layout);
				ctx.fill();

				log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Set speed tick: %s",
						text);

				ctx.move_to(-4, j);
				ctx.line_to(0, j);
				ctx.stroke();
				/* */
			}

			/* Draw axis */
			ctx.set_line_width(1.5);
			ctx.set_source_rgba(0.0, 0.0, 0.0, 1);
			ctx.move_to(0.0, 0.0);
			ctx.line_to(0.0,graph_height);
			ctx.stroke();

			ctx.line_to(0.0, graph_height+(graph_height/range)*(min_value));
			ctx.line_to(graph_width, graph_height+(graph_height/range)*(min_value));
			ctx.stroke();

			log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Draw Axis"); 

			/* Draw the graph */
			ctx.set_source_rgba(0.1, 0.2, 0.3, 1);
			ctx.set_line_width(1);
			weak List<Point?> iter = track.points.first();
			ctx.move_to(0.0, graph_height*(1+min_value/range));


			double pref_speed = 2f;
            double pref_speed_threshold = 1f;
            // If pref_speed drops below this threshold we drop a 0 speed 
            // point. 1/20 of average atm.
            // This is used below to make sure that when there was motion (and therefor no new points)
            // the start/stop point are not connect with a straight line, but actually a 0 speed line is drawn.

            if(this.mode == GraphMode.SPEED) {
				var avg = track.get_track_average();
                pref_speed_threshold = avg/20;
            }
			while(iter.next != null)
			{
				double time_offset = (iter.data.get_time()-f.get_time());
				double speed = 0;
				weak List<Point?> ii = iter.next;
				int i=0;
				int sf = this.smooth_factor;
				for(i=0;i< sf && ii.prev != null; i++)
				{
					if(this.mode == GraphMode.SPEED) {
						speed += track.calculate_point_to_point_speed(ii.prev.data, ii.data);
					}else if(this.mode == GraphMode.ELEVATION){
						speed += ii.data.elevation-min_value;
					}else if(this.mode == GraphMode.DISTANCE){
						speed += ii.data.distance;
					}else if (this.mode == GraphMode.ACCELERATION_H) {
                        speed += (ii.data.speed - ii.prev.data.speed)/(3.6*(ii.data.get_time()-ii.prev.data.get_time()))-min_value;
					}else if (this.mode == GraphMode.ACCELERATION_V) {
                        speed += (ii.data.elevation - ii.prev.data.elevation)/(3.6*(ii.data.get_time()-ii.prev.data.get_time()))-min_value;
                    }
					ii = ii.prev;
				}
				speed = speed/i;

                // if speed on previous point lower then pref_speed, start at 0.
				if(this.mode == GraphMode.SPEED && pref_speed < pref_speed_threshold) {
					ctx.line_to(graph_width*(double)(time_offset/(double)elapsed_time),
							graph_height*(double)(1.0-0));

				}

				ctx.line_to(graph_width*(double)(time_offset/(double)elapsed_time),
						graph_height*(double)(1.0-speed/(range)));

                // if speed on current point was very low, end at 0
				if(this.mode == GraphMode.SPEED && speed < pref_speed_threshold) {
					ctx.line_to(graph_width*(double)(time_offset/(double)elapsed_time),
							graph_height*(double)(1.0-0));

				}
				iter = iter.next;

				pref_speed = speed;
			}
			ctx.line_to(graph_width, graph_height*(1+min_value/range));
			ctx.close_path();
			ctx.stroke_preserve();

			ctx.set_source_rgba(0.1, 0.2, 0.8, 0.5);
			ctx.fill();

			if (this.show_points) {
				log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Draw data points"); 
				/* Draw points */
				ctx.set_source_rgba(0.0, 0.0, 0.0, 1.0);
				iter = track.points.first();
				while(iter.next != null)
				{
					double time_offset = (iter.data.get_time()-f.get_time());
					double speed = 0;
					weak List<Point?> ii = iter.next;
					int i=0;
					int sf = this.smooth_factor;
					for(i=0;i< sf && ii.prev != null; i++)
					{
						if(this.mode == GraphMode.SPEED) {
							speed += track.calculate_point_to_point_speed(ii.prev.data, ii.data)-min_value;
						}else if(this.mode == GraphMode.ELEVATION){
							speed += ii.data.elevation-min_value;
						}else if(this.mode == GraphMode.DISTANCE){
							speed += ii.data.distance;
						}else if(this.mode == GraphMode.ACCELERATION_H){
							speed += (ii.data.speed- ii.prev.data.speed)/(3.6*(ii.data.get_time()-ii.prev.data.get_time()))-min_value;
						}else if(this.mode == GraphMode.ACCELERATION_V){
							speed += (ii.data.elevation- ii.prev.data.elevation)/(3.6*(ii.data.get_time()-ii.prev.data.get_time()))-min_value;
                        }
						ii = ii.prev;
					}
					speed = speed/i;
					ctx.rectangle(graph_width*(double)(time_offset/(double)elapsed_time)-1,
							graph_height*(double)(1.0-speed/(range))-1,2,2);
					ctx.stroke();

					iter = iter.next;
				}
			}

			log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Draw graph"); 

			iter = track.points.first();

			ctx.set_source_rgba(0.0, 0.0, 0.0, 1.0);
			fd.set_absolute_size(12*1024);
			layout.set_font_description(fd);
			uint interval = (uint)elapsed_time/((uint)(graph_width/(5*12.0)));
			int current = 0;
			uint i;
			for(i=0; i < elapsed_time && interval > 0; i+= interval)
			{
				if(graph_width*(1-(i/elapsed_time)) > 2.5*12 ){
					int w,h;
					var text = "%02i:%02i".printf((int)i/3600, ((int)i%3600)/60);
					layout.set_text(text,-1);
					layout.get_pixel_size(out w, out h);
					ctx.move_to(graph_width*(double)(i/elapsed_time)-w/2.0, graph_height+10);
					Pango.cairo_layout_path(ctx, layout);
					ctx.fill();

					log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Set time tick: %s",
							text);

					ctx.move_to(graph_width*(double)(i/elapsed_time), graph_height);
					ctx.line_to(graph_width*(double)(i/elapsed_time), graph_height+5);
					ctx.stroke();
				}
				current++;
			}

			/* Draw average speed */
			if(this.mode == GraphMode.SPEED)
			{
				var avg = track.get_track_average();
				ctx.set_source_rgba(0.0, 0.7, 0.0, 0.7);
				ctx.move_to(0.0, graph_height*(1-avg/max_value));
				ctx.line_to(graph_width, graph_height*(1-avg/max_value));
				ctx.stroke();
				log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Draw average speed line @ %.02f km/h", avg);

				/* Draw moving speed */
				time_t moving_time;
				avg = track.calculate_moving_average(this.track.points.first().data, this.track.points.last().data,out moving_time);
				ctx.set_source_rgba(0.7, 0.0, 0.0, 0.7);
				ctx.move_to(0.0, graph_height*(1-avg/max_value));
				ctx.line_to(graph_width, graph_height*(1-avg/max_value));
				ctx.stroke();

				log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Draw moving average speed line @ %.02f km/h", avg);
			}

			/* Draw the title */
			int w,h;
			ctx.set_source_rgba(0.0, 0.0, 0.0, 1.0);
			fd.set_absolute_size(12*1024);
			layout.set_font_description(fd);
			string mtext = _(this.GraphModeName[this.mode]);
			if(this.smooth_factor != 1)
			{
				var markup = _("%s <i>(smooth window: %i)</i>").printf(mtext,this.smooth_factor);
				layout.set_markup(markup,-1);
				log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Set graph title: %s",
						markup);
			}
			else
			{
				layout.set_text(mtext,-1);
				log(LOG_DOMAIN, LogLevelFlags.LEVEL_DEBUG, "Set graph title: %s",
						mtext);
			}
			layout.get_pixel_size(out w, out h);
			ctx.move_to(graph_width/2-w/2, -20);
			Pango.cairo_layout_path(ctx, layout);
			ctx.fill();
		}
	}
}

/* vim: set noexpandtab ts=4 sw=4 sts=4 tw=120: */
