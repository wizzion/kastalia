// Generated by CoffeeScript 1.10.0
(function() {
  var BBoxSelector;

  BBoxSelector = (function() {
    function BBoxSelector(image_frame, options) {
      if (options == null) {
        options = {};
      }
      options.input_method || (options.input_method = "text");
      this.image_frame = image_frame;
      this.border_width = options.border_width || 2;
      this.selector = $('<div class="bbox_selector"></div>');
      this.selector.css({
        "border": this.border_width + "px dotted rgb(127,255,127)",
        "position": "absolute"
      });
      this.image_frame.append(this.selector);
      this.selector.css({
        "border-width": this.border_width
      });
      this.selector.hide();
      this.create_ocr_box(options);
    }

    BBoxSelector.prototype.create_ocr_box = function(options) {
      var i, ocr, len, ref;
      options.ocrs || (options.ocrs = ["object"]);
      this.ocr_box = $('<div class="ocr_box"></div>');
      this.ocr_box.css({
        "position": "absolute"
      });
      this.image_frame.append(this.ocr_box);
      switch (options.input_method) {
        case 'select':
          if (typeof options.ocrs === "string") {
            options.ocrs = [options.ocrs];
          }
          this.ocr_input = $('<select class="ocr_input" name="ocr"></select>');
          this.ocr_box.append(this.ocr_input);
          this.ocr_input.append($('<option value>choose an item</option>'));
          ref = options.ocrs;
          for (i = 0, len = ref.length; i < len; i++) {
            ocr = ref[i];
            this.ocr_input.append('<option value="' + ocr + '">' + ocr + '</option>');
          }
          this.ocr_input.change(function(e) {
            return this.blur();
          });
          break;
        case 'text':
          if (typeof options.ocrs === "string") {
            options.ocrs = [options.ocrs];
          }
          this.ocr_input = $('<input class="ocr_input" name="ocr" ' + 'type="text" value>');
          this.ocr_box.append(this.ocr_input);
          this.ocr_input.autocomplete({
            source: options.ocrs || [''],
            autoFocus: true
          });
          break;
        case 'fixed':
          if ($.isArray(options.ocrs)) {
            options.ocrs = options.ocrs[0];
          }
          this.ocr_input = $('<input class="ocr_input" name="ocr" type="text">');
          this.ocr_box.append(this.ocr_input);
          this.ocr_input.val(options.ocrs);
          break;
        default:
          throw 'Invalid ocr_input parameter: ' + options.input_method;
      }
      return this.ocr_box.hide();
    };

    BBoxSelector.prototype.crop = function(pageX, pageY) {
      var point;
      return point = {
        x: Math.min(Math.max(Math.round(pageX - this.image_frame.offset().left), 0), Math.round(this.image_frame.width() - 1)),
        y: Math.min(Math.max(Math.round(pageY - this.image_frame.offset().top), 0), Math.round(this.image_frame.height() - 1))
      };
    };

    BBoxSelector.prototype.start = function(pageX, pageY) {
      this.pointer = this.crop(pageX, pageY);
      this.offset = this.pointer;
      this.refresh();
      this.selector.show();
      $('body').css('cursor', 'crosshair');
      return document.onselectstart = function() {
        return false;
      };
    };

    BBoxSelector.prototype.update_rectangle = function(pageX, pageY) {
      this.pointer = this.crop(pageX, pageY);
      return this.refresh();
    };

    BBoxSelector.prototype.input_ocr = function(options) {
      $('body').css('cursor', 'default');
      document.onselectstart = function() {
        return true;
      };
      this.ocr_box.show();
      return this.ocr_input.focus();
    };

    BBoxSelector.prototype.finish = function(options) {
      var data;
      this.ocr_box.hide();
      this.selector.hide();
      data = this.rectangle();
      //data.ocr = $.trim(this.ocr_input.val().toLowerCase());
      data.ocr = $.trim(this.ocr_input.val());
      if (options.input_method !== 'fixed') {
        this.ocr_input.val('');
      }
      return data;
    };

    BBoxSelector.prototype.rectangle = function() {
      var rect, x1, x2, y1, y2;
      x1 = Math.min(this.offset.x, this.pointer.x);
      y1 = Math.min(this.offset.y, this.pointer.y);
      x2 = Math.max(this.offset.x, this.pointer.x);
      y2 = Math.max(this.offset.y, this.pointer.y);
      return rect = {
        left: x1,
        top: y1,
        width: x2 - x1 + 1,
        height: y2 - y1 + 1
      };
    };

    BBoxSelector.prototype.refresh = function() {
      var rect;
      rect = this.rectangle();
      this.selector.css({
        left: (rect.left - this.border_width) + 'px',
        top: (rect.top - this.border_width) + 'px',
        width: rect.width + 'px',
        height: rect.height + 'px'
      });
      return this.ocr_box.css({
        left: (rect.left - this.border_width) + 'px',
        top: (rect.top + rect.height + this.border_width) + 'px'
      });
    };

    BBoxSelector.prototype.get_input_element = function() {
      return this.ocr_input;
    };

    return BBoxSelector;

  })();

  this.BBoxAnnotator = (function() {
    function BBoxAnnotator(options) {
      var annotator, image_element;
      annotator = this;
      this.annotator_element = $(options.id || "#bbox_annotator");
      this.border_width = options.border_width || 2;
      this.show_ocr = options.show_ocr || (options.input_method !== "fixed");
      this.image_frame = $('<div class="image_frame"></div>');
      this.annotator_element.append(this.image_frame);
      image_element = new Image();
      image_element.src = options.url;
      image_element.onload = function() {
	boxes.forEach(element=>{
		element.width*=image_element.width;
		element.height*=image_element.height;
		element.left*=image_element.width;
		element.top*=image_element.height;
		annotator.add_entry(element)});

        $("#annotation_data").text(JSON.stringify(annotator.entries, null, "  "));
	options.width || (options.width = image_element.width);
        options.height || (options.height = image_element.height);
        annotator.annotator_element.css({
          "width": (options.width + annotator.border_width * 2) + 'px',
          "height": (options.height + annotator.border_width * 2) + 'px',
          "cursor": "crosshair"
        });
        annotator.image_frame.css({
          "background-image": "url('" + image_element.src + "')",
          "width": options.width + "px",
          "height": options.height + "px",
          "position": "relative"
        });
        annotator.selector = new BBoxSelector(annotator.image_frame, options);
        return annotator.initialize_events(annotator.selector, options);
      };
      image_element.onerror = function() {
        return annotator.annotator_element.text("Invalid image URL: " + options.url);
      };
      this.entries = [];
      this.onchange = options.onchange;
    }

    BBoxAnnotator.prototype.initialize_events = function(selector, options) {
      var annotator, status;
      status = 'free';
      this.hit_menuitem = false;
      annotator = this;
      this.annotator_element.mousedown(function(e) {
        if (!annotator.hit_menuitem) {
          switch (status) {
            case 'free':
            case 'input':
              if (status === 'input') {
                selector.get_input_element().blur();
              }
              if (e.which === 1) {
                selector.start(e.pageX, e.pageY);
                status = 'hold';
              }
          }
        }
        annotator.hit_menuitem = false;
        return true;
      });
      $(window).mousemove(function(e) {
        switch (status) {
          case 'hold':
            selector.update_rectangle(e.pageX, e.pageY);
        }
        return true;
      });
      $(window).mouseup(function(e) {
        switch (status) {
          case 'hold':
            selector.update_rectangle(e.pageX, e.pageY);
            selector.input_ocr(options);
            status = 'input';
            if (options.input_method === 'fixed') {
              selector.get_input_element().blur();
            }
        }
        return true;
      });
      selector.get_input_element().blur(function(e) {
        var data;
        switch (status) {
          case 'input':
            data = selector.finish(options);
            if (data.ocr) {
              annotator.add_entry(data);
              if (annotator.onchange) {
                annotator.onchange(annotator.entries);
              }
            }
            status = 'free';
        }
        return true;
      });
      selector.get_input_element().keypress(function(e) {
        switch (status) {
          case 'input':
            if (e.which === 13) {
              selector.get_input_element().blur();
            }
        }
        return e.which !== 13;
      });
      selector.get_input_element().mousedown(function(e) {
        return annotator.hit_menuitem = true;
      });
      selector.get_input_element().mousemove(function(e) {
        return annotator.hit_menuitem = true;
      });
      selector.get_input_element().mouseup(function(e) {
        return annotator.hit_menuitem = true;
      });
      return selector.get_input_element().parent().mousedown(function(e) {
        return annotator.hit_menuitem = true;
      });
    };

    BBoxAnnotator.prototype.add_entry = function(entry) {
      var annotator, box_element, close_button, text_box;
      this.entries.push(entry);
      box_element = $('<div id="'+entry.id+'" class="annotated_bounding_box"></div>');
      box_element.appendTo(this.image_frame).css({
        "border": this.border_width + "px solid rgb(127,255,127)",
        "position": "absolute",
        "top": (entry.top - this.border_width) + "px",
        "left": (entry.left - this.border_width) + "px",
        "width": entry.width + "px",
        "height": entry.height + "px",
        "color": "rgb(255,0,0)",
        "font-family": "monospace",
        "font-size": "20px"
      });
      close_button = $('<div></div>').appendTo(box_element).css({
        "position": "absolute",
        "top": "-8px",
        "right": "-8px",
        "width": "16px",
        "height": "0",
        "padding": "16px 0 0 0",
        "overflow": "hidden",
        "color": "#fff",
        "background-color": "#030",
        "border": "2px solid #fff",
        "-moz-border-radius": "18px",
        "-webkit-border-radius": "18px",
        "border-radius": "18px",
        "cursor": "pointer",
        "-moz-user-select": "none",
        "-webkit-user-select": "none",
        "user-select": "none",
        "text-align": "center"
      });
      $("<div></div>").appendTo(close_button).html('&#215;').css({
        "display": "block",
        "text-align": "center",
        "width": "16px",
        "position": "absolute",
        "top": "-2px",
        "left": "0",
        "font-size": "16px",
        "line-height": "16px",
        "font-family": '"Helvetica Neue", Consolas, Verdana, Tahoma, Calibri, ' + 'Helvetica, Menlo, "Droid Sans", sans-serif'
      });
      text_box = $('<div></div>').appendTo(box_element).css({
        "overflow": "hidden"
      });
      if (this.show_ocr) {
        text_box.text(entry.ocr);
      }
      annotator = this;
      box_element.hover((function(e) {
        return close_button.show();
      }), (function(e) {
        return close_button.hide();
      }));
      close_button.mousedown(function(e) {
        return annotator.hit_menuitem = true;
      });
      close_button.click(function(e) {
        var clicked_box, index;
        clicked_box = close_button.parent(".annotated_bounding_box");
        index = clicked_box.prevAll(".annotated_bounding_box").length;
        clicked_box.detach();
        annotator.entries.splice(index, 1);
        return annotator.onchange(annotator.entries);
      });
      return close_button.hide();
    };

    BBoxAnnotator.prototype.clear_all = function(e) {
      this.annotator_element.find(".annotated_bounding_box").detach();
      this.entries.splice(0);
      return this.onchange(this.entries);
    };

    return BBoxAnnotator;

  })();

}).call(this);
