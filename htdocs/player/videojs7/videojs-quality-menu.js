/*! @name @brightcove/videojs-quality-menu @version 1.4.0 @license UNLICENSED */
(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('video.js'), require('global/document')) :
  typeof define === 'function' && define.amd ? define(['video.js', 'global/document'], factory) :
  (global = global || self, global.videojsQualityMenu = factory(global.videojs, global.document));
}(this, (function (videojs, document) { 'use strict';

  videojs = videojs && videojs.hasOwnProperty('default') ? videojs['default'] : videojs;
  document = document && document.hasOwnProperty('default') ? document['default'] : document;

  /*! @name videojs-contrib-quality-levels @version 2.0.9 @license Apache-2.0 */

  function _inheritsLoose(subClass, superClass) {
    subClass.prototype = Object.create(superClass.prototype);
    subClass.prototype.constructor = subClass;
    subClass.__proto__ = superClass;
  }

  function _assertThisInitialized(self) {
    if (self === void 0) {
      throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
    }

    return self;
  }

  /**
   * A single QualityLevel.
   *
   * interface QualityLevel {
   *   readonly attribute DOMString id;
   *            attribute DOMString label;
   *   readonly attribute long width;
   *   readonly attribute long height;
   *   readonly attribute long bitrate;
   *            attribute boolean enabled;
   * };
   *
   * @class QualityLevel
   */

  var QualityLevel =
  /**
   * Creates a QualityLevel
   *
   * @param {Representation|Object} representation The representation of the quality level
   * @param {string}   representation.id        Unique id of the QualityLevel
   * @param {number=}  representation.width     Resolution width of the QualityLevel
   * @param {number=}  representation.height    Resolution height of the QualityLevel
   * @param {number}   representation.bandwidth Bitrate of the QualityLevel
   * @param {Function} representation.enabled   Callback to enable/disable QualityLevel
   */
  function QualityLevel(representation) {
    var level = this; // eslint-disable-line

    if (videojs.browser.IS_IE8) {
      level = document.createElement('custom');

      for (var prop in QualityLevel.prototype) {
        if (prop !== 'constructor') {
          level[prop] = QualityLevel.prototype[prop];
        }
      }
    }

    level.id = representation.id;
    level.label = level.id;
    level.width = representation.width;
    level.height = representation.height;
    level.bitrate = representation.bandwidth;
    level.enabled_ = representation.enabled;
    Object.defineProperty(level, 'enabled', {
      /**
       * Get whether the QualityLevel is enabled.
       *
       * @return {boolean} True if the QualityLevel is enabled.
       */
      get: function get() {
        return level.enabled_();
      },

      /**
       * Enable or disable the QualityLevel.
       *
       * @param {boolean} enable true to enable QualityLevel, false to disable.
       */
      set: function set(enable) {
        level.enabled_(enable);
      }
    });
    return level;
  };

  /**
   * A list of QualityLevels.
   *
   * interface QualityLevelList : EventTarget {
   *   getter QualityLevel (unsigned long index);
   *   readonly attribute unsigned long length;
   *   readonly attribute long selectedIndex;
   *
   *   void addQualityLevel(QualityLevel qualityLevel)
   *   void removeQualityLevel(QualityLevel remove)
   *   QualityLevel? getQualityLevelById(DOMString id);
   *
   *   attribute EventHandler onchange;
   *   attribute EventHandler onaddqualitylevel;
   *   attribute EventHandler onremovequalitylevel;
   * };
   *
   * @extends videojs.EventTarget
   * @class QualityLevelList
   */

  var QualityLevelList =
  /*#__PURE__*/
  function (_videojs$EventTarget) {
    _inheritsLoose(QualityLevelList, _videojs$EventTarget);

    function QualityLevelList() {
      var _this;

      _this = _videojs$EventTarget.call(this) || this;

      var list = _assertThisInitialized(_assertThisInitialized(_this)); // eslint-disable-line


      if (videojs.browser.IS_IE8) {
        list = document.createElement('custom');

        for (var prop in QualityLevelList.prototype) {
          if (prop !== 'constructor') {
            list[prop] = QualityLevelList.prototype[prop];
          }
        }
      }

      list.levels_ = [];
      list.selectedIndex_ = -1;
      /**
       * Get the index of the currently selected QualityLevel.
       *
       * @returns {number} The index of the selected QualityLevel. -1 if none selected.
       * @readonly
       */

      Object.defineProperty(list, 'selectedIndex', {
        get: function get() {
          return list.selectedIndex_;
        }
      });
      /**
       * Get the length of the list of QualityLevels.
       *
       * @returns {number} The length of the list.
       * @readonly
       */

      Object.defineProperty(list, 'length', {
        get: function get() {
          return list.levels_.length;
        }
      });
      return list || _assertThisInitialized(_this);
    }
    /**
     * Adds a quality level to the list.
     *
     * @param {Representation|Object} representation The representation of the quality level
     * @param {string}   representation.id        Unique id of the QualityLevel
     * @param {number=}  representation.width     Resolution width of the QualityLevel
     * @param {number=}  representation.height    Resolution height of the QualityLevel
     * @param {number}   representation.bandwidth Bitrate of the QualityLevel
     * @param {Function} representation.enabled   Callback to enable/disable QualityLevel
     * @return {QualityLevel} the QualityLevel added to the list
     * @method addQualityLevel
     */


    var _proto = QualityLevelList.prototype;

    _proto.addQualityLevel = function addQualityLevel(representation) {
      var qualityLevel = this.getQualityLevelById(representation.id); // Do not add duplicate quality levels

      if (qualityLevel) {
        return qualityLevel;
      }

      var index = this.levels_.length;
      qualityLevel = new QualityLevel(representation);

      if (!('' + index in this)) {
        Object.defineProperty(this, index, {
          get: function get() {
            return this.levels_[index];
          }
        });
      }

      this.levels_.push(qualityLevel);
      this.trigger({
        qualityLevel: qualityLevel,
        type: 'addqualitylevel'
      });
      return qualityLevel;
    };
    /**
     * Removes a quality level from the list.
     *
     * @param {QualityLevel} remove QualityLevel to remove to the list.
     * @return {QualityLevel|null} the QualityLevel removed or null if nothing removed
     * @method removeQualityLevel
     */


    _proto.removeQualityLevel = function removeQualityLevel(qualityLevel) {
      var removed = null;

      for (var i = 0, l = this.length; i < l; i++) {
        if (this[i] === qualityLevel) {
          removed = this.levels_.splice(i, 1)[0];

          if (this.selectedIndex_ === i) {
            this.selectedIndex_ = -1;
          } else if (this.selectedIndex_ > i) {
            this.selectedIndex_--;
          }

          break;
        }
      }

      if (removed) {
        this.trigger({
          qualityLevel: qualityLevel,
          type: 'removequalitylevel'
        });
      }

      return removed;
    };
    /**
     * Searches for a QualityLevel with the given id.
     *
     * @param {string} id The id of the QualityLevel to find.
     * @return {QualityLevel|null} The QualityLevel with id, or null if not found.
     * @method getQualityLevelById
     */


    _proto.getQualityLevelById = function getQualityLevelById(id) {
      for (var i = 0, l = this.length; i < l; i++) {
        var level = this[i];

        if (level.id === id) {
          return level;
        }
      }

      return null;
    };
    /**
     * Resets the list of QualityLevels to empty
     *
     * @method dispose
     */


    _proto.dispose = function dispose() {
      this.selectedIndex_ = -1;
      this.levels_.length = 0;
    };

    return QualityLevelList;
  }(videojs.EventTarget);
  /**
   * change - The selected QualityLevel has changed.
   * addqualitylevel - A QualityLevel has been added to the QualityLevelList.
   * removequalitylevel - A QualityLevel has been removed from the QualityLevelList.
   */


  QualityLevelList.prototype.allowedEvents_ = {
    change: 'change',
    addqualitylevel: 'addqualitylevel',
    removequalitylevel: 'removequalitylevel'
  }; // emulate attribute EventHandler support to allow for feature detection

  for (var event in QualityLevelList.prototype.allowedEvents_) {
    QualityLevelList.prototype['on' + event] = null;
  }

  var version = "2.0.9";

  var registerPlugin = videojs.registerPlugin || videojs.plugin;
  /**
   * Initialization function for the qualityLevels plugin. Sets up the QualityLevelList and
   * event handlers.
   *
   * @param {Player} player Player object.
   * @param {Object} options Plugin options object.
   * @function initPlugin
   */

  var initPlugin = function initPlugin(player, options) {
    var originalPluginFn = player.qualityLevels;
    var qualityLevelList = new QualityLevelList();

    var disposeHandler = function disposeHandler() {
      qualityLevelList.dispose();
      player.qualityLevels = originalPluginFn;
      player.off('dispose', disposeHandler);
    };

    player.on('dispose', disposeHandler);

    player.qualityLevels = function () {
      return qualityLevelList;
    };

    player.qualityLevels.VERSION = version;
    return qualityLevelList;
  };
  /**
   * A video.js plugin.
   *
   * In the plugin function, the value of `this` is a video.js `Player`
   * instance. You cannot rely on the player being in a "ready" state here,
   * depending on how the plugin is invoked. This may or may not be important
   * to you; if not, remove the wait for "ready"!
   *
   * @param {Object} options Plugin options object
   * @function qualityLevels
   */


  var qualityLevels = function qualityLevels(options) {
    return initPlugin(this, videojs.mergeOptions({}, options));
  }; // Register the plugin with video.js.


  registerPlugin('qualityLevels', qualityLevels); // Include the version number.

  qualityLevels.VERSION = version;

  function _assertThisInitialized$1(self) {
    if (self === void 0) {
      throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
    }

    return self;
  }

  var assertThisInitialized = _assertThisInitialized$1;

  function _inheritsLoose$1(subClass, superClass) {
    subClass.prototype = Object.create(superClass.prototype);
    subClass.prototype.constructor = subClass;
    subClass.__proto__ = superClass;
  }

  var inheritsLoose = _inheritsLoose$1;

  var MenuItem = videojs.getComponent('MenuItem');
  var dom = videojs.dom || videojs;
  /**
   * The quality level menu quality
   *
   * @extends MenuItem
   * @class QualityMenuItem
   */

  var QualityMenuItem =
  /*#__PURE__*/
  function (_MenuItem) {
    inheritsLoose(QualityMenuItem, _MenuItem);

    /**
     * Creates a QualityMenuItem
     *
     * @param {Player|Object} player
     *        Main Player
     * @param {Object} [options]
     *        Options for menu item
     * @param {number[]} options.levels
     *        Array of indices mapping to QualityLevels in the QualityLevelList for
     *        this menu item
     * @param {string} options.label
     *        Label for this menu item
     * @param {string} options.controlText
     *        control text for this menu item
     * @param {string} options.subLabel
     *        sub label text for this menu item
     * @param {boolean} options.active
     *        True if the QualityLevelList.selectedIndex is contained in the levels list
     *        for this menu
     * @param {boolean} options.selected
     *        True if this menu item is the selected item in the UI
     * @param {boolean} options.selectable
     *        True if this menu item should be selectable in the UI
     */
    function QualityMenuItem(player, options) {
      var _this;

      if (options === void 0) {
        options = {};
      }

      var selectedOption = options.selected; // We need to change options.seleted to options.active because the call to super
      // causes us to run MenuItem's constructor which calls this.selected(options.selected)
      // However, for QualityMenuItem, we change the meaning of the parameter to
      // this.selected() to be what we mean for 'active' which is True if the
      // QualityLevelList.selectedIndex is contained in the levels list for this menu

      options.selected = options.active;
      _this = _MenuItem.call(this, player, options) || this;
      var qualityLevels = player.qualityLevels();
      _this.levels_ = options.levels;
      _this.selected_ = selectedOption;
      _this.handleQualityChange = _this.handleQualityChange.bind(assertThisInitialized(_this));

      _this.controlText(options.controlText);

      _this.on(qualityLevels, 'change', _this.handleQualityChange);

      _this.on('dispose', function () {
        _this.off(qualityLevels, 'change', _this.handleQualityChange);
      });

      return _this;
    }
    /**
     * Create the component's DOM element
     *
     * @param {string} [type]
     *        Element type
     * @param {Object} [props]
     *        Element properties
     * @param {Object} [attrs]
     *        An object of attributes that should be set on the element
     * @return {Element}
     *         The DOM element
     * @method createEl
     */


    var _proto = QualityMenuItem.prototype;

    _proto.createEl = function createEl(type, props, attrs) {
      var el = _MenuItem.prototype.createEl.call(this, type, props, attrs);

      var subLabel = dom.createEl('span', {
        className: 'vjs-quality-menu-item-sub-label',
        innerHTML: this.localize(this.options_.subLabel || '')
      });
      this.subLabel_ = subLabel;

      if (el) {
        el.appendChild(subLabel);
      }

      return el;
    }
    /**
     * Handle a click on the menu item, and set it to selected
     *
     * @method handleClick
     */
    ;

    _proto.handleClick = function handleClick() {
      this.updateSiblings_();
      var qualityLevels = this.player().qualityLevels();
      var currentlySelected = qualityLevels.selectedIndex;

      for (var i = 0, l = qualityLevels.length; i < l; i++) {
        // do not disable the currently selected quality until the end to prevent
        // playlist selection from selecting something new until we've enabled/disabled
        // all the quality levels
        if (i !== currentlySelected) {
          qualityLevels[i].enabled = false;
        }
      }

      for (var _i = 0, _l = this.levels_.length; _i < _l; _i++) {
        qualityLevels[this.levels_[_i]].enabled = true;
      } // Disable the quality level that was selected before the click if it is not
      // associated with this menu item


      if (currentlySelected !== -1 && this.levels_.indexOf(currentlySelected) === -1) {
        qualityLevels[currentlySelected].enabled = false;
      }
    }
    /**
     * Handle a change event from the QualityLevelList
     *
     * @method handleQualityChange
     */
    ;

    _proto.handleQualityChange = function handleQualityChange() {
      var qualityLevels = this.player().qualityLevels();
      var active = this.levels_.indexOf(qualityLevels.selectedIndex) > -1;
      this.selected(active);
    }
    /**
     * Set this menu item as selected or not
     *
     * @param  {boolean} active
     *         True if the active quality level is controlled by this item
     * @method selected
     */
    ;

    _proto.selected = function selected(active) {
      if (!this.selectable) {
        return;
      }

      if (this.selected_) {
        this.addClass('vjs-selected');
        this.el_.setAttribute('aria-checked', 'true'); // aria-checked isn't fully supported by browsers/screen readers,
        // so indicate selected state to screen reader in the control text.

        this.controlText(this.localize('{1}, selected', this.localize(this.options_.controlText)));
        var controlBar = this.player().controlBar;
        var menuButton = controlBar.getChild('QualityMenuButton');

        if (!active) {
          // This menu item is manually selected but the current playing quality level
          // is NOT associated with this menu item. This can happen if the quality hasnt
          // changed yet or something went wrong with rendition selection such as failed
          // server responses for playlists
          menuButton.addClass('vjs-quality-menu-button-waiting');
        } else {
          menuButton.removeClass('vjs-quality-menu-button-waiting');
        }
      } else {
        this.removeClass('vjs-selected');
        this.el_.setAttribute('aria-checked', 'false'); // Indicate un-selected state to screen reader
        // Note that a space clears out the selected state text

        this.controlText(this.options_.controlText);
      }
    }
    /**
     * Sets this QualityMenuItem to be selected and deselects the other items
     *
     * @method updateSiblings_
     */
    ;

    _proto.updateSiblings_ = function updateSiblings_() {
      var qualityLevels = this.player().qualityLevels();
      var controlBar = this.player().controlBar;
      var menuItems = controlBar.getChild('QualityMenuButton').items;

      for (var i = 0, l = menuItems.length; i < l; i++) {
        var item = menuItems[i];
        var active = item.levels_.indexOf(qualityLevels.selectedIndex) > -1;
        item.selected_ = item === this;
        item.selected(active);
      }
    };

    return QualityMenuItem;
  }(MenuItem);

  var MenuButton = videojs.getComponent('MenuButton');
  /**
   * Checks whether all the QualityLevels in a QualityLevelList have resolution information
   *
   * @param {QualityLevelList} qualityLevelList
   *        The list of QualityLevels
   * @return {boolean}
   *         True if all levels have resolution information, false otherwise
   * @function hasResolutionInfo
   */

  var hasResolutionInfo = function hasResolutionInfo(qualityLevelList) {
    for (var i = 0, l = qualityLevelList.length; i < l; i++) {
      if (!qualityLevelList[i].height) {
        return false;
      }
    }

    return true;
  };
  /**
   * Determines the appropriate sub label for the given lines of resolution
   *
   * @param {number} lines
   *        The horizontal lines of resolution
   * @return {string}
   *         sub label for given resolution
   * @function getSubLabel
   */


  var getSubLabel = function getSubLabel(lines) {
    if (lines >= 2160) {
      return '4K';
    }

    if (lines >= 720) {
      return 'HD';
    }

    return '';
  };
  /**
   * The component for controlling the quality menu
   *
   * @extends MenuButton
   * @class QualityMenuButton
   */


  var QualityMenuButton =
  /*#__PURE__*/
  function (_MenuButton) {
    inheritsLoose(QualityMenuButton, _MenuButton);

    /**
     * Creates a QualityMenuButton
     *
     * @param {Player|Object} player
     *        Main Player
     * @param {Object} [options]
     *        Options for QualityMenuButton
     */
    function QualityMenuButton(player, options) {
      var _this;

      if (options === void 0) {
        options = {};
      }

      _this = _MenuButton.call(this, player, options) || this;

      _this.el_.setAttribute('aria-label', _this.localize('Quality Levels'));

      _this.controlText('Quality Levels');

      _this.qualityLevels_ = player.qualityLevels();
      _this.update = _this.update.bind(assertThisInitialized(_this));
      _this.handleQualityChange_ = _this.handleQualityChange_.bind(assertThisInitialized(_this));

      _this.changeHandler_ = function () {
        var defaultResolution = _this.options_.defaultResolution;

        for (var i = 0; i < _this.items.length; i++) {
          if (_this.items[i].options_.label.indexOf(defaultResolution) !== -1) {
            _this.items[i].handleClick();
          }
        }
      };

      _this.on(_this.qualityLevels_, 'addqualitylevel', _this.update);

      _this.on(_this.qualityLevels_, 'removequalitylevel', _this.update);

      _this.on(_this.qualityLevels_, 'change', _this.handleQualityChange_);

      _this.one(_this.qualityLevels_, 'change', _this.changeHandler_);

      _this.update();

      _this.on('dispose', function () {
        _this.off(_this.qualityLevels_, 'addqualitylevel', _this.update);

        _this.off(_this.qualityLevels_, 'removequalitylevel', _this.update);

        _this.off(_this.qualityLevels_, 'change', _this.handleQualityChange_);

        _this.off(_this.qualityLevels_, 'change', _this.changeHandler_);
      });

      return _this;
    }
    /**
     * Allow sub components to stack CSS class names
     *
     * @return {string}
     *         The constructed class name
     * @method buildWrapperCSSClass
     */


    var _proto = QualityMenuButton.prototype;

    _proto.buildWrapperCSSClass = function buildWrapperCSSClass() {
      return "vjs-quality-menu-wrapper " + _MenuButton.prototype.buildWrapperCSSClass.call(this);
    }
    /**
     * Allow sub components to stack CSS class names
     *
     * @return {string}
     *         The constructed class name
     * @method buildCSSClass
     */
    ;

    _proto.buildCSSClass = function buildCSSClass() {
      return "vjs-quality-menu-button " + _MenuButton.prototype.buildCSSClass.call(this);
    }
    /**
     * Create the list of menu items.
     *
     * @return {Array}
     *         The list of menu items
     * @method createItems
     */
    ;

    _proto.createItems = function createItems() {
      var _this2 = this;

      var items = [];

      if (!(this.qualityLevels_ && this.qualityLevels_.length)) {
        return items;
      }

      var groups;

      if (this.options_.useResolutionLabels && hasResolutionInfo(this.qualityLevels_)) {
        groups = this.groupByResolution_();
        this.addClass('vjs-quality-menu-button-use-resolution');
      } else {
        groups = this.groupByBitrate_();
        this.removeClass('vjs-quality-menu-button-use-resolution');
      } // if there is only 1 or 0 menu items, we should just return an empty list so
      // the ui does not appear when there are no options. We consider 1 to be no options
      // since Auto will have the same behavior as selecting the only other option,
      // so it is as effective as not having any options.


      if (groups.length <= 1) {
        return [];
      }

      groups.forEach(function (group) {
        if (group.levels.length) {
          group.selectable = true;
          items.push(new QualityMenuItem(_this2.player(), group));
        }
      }); // Add the Auto menu item

      var auto = new QualityMenuItem(this.player(), {
        levels: Array.prototype.map.call(this.qualityLevels_, function (level, i) {
          return i;
        }),
        label: 'Auto',
        controlText: 'Auto',
        active: true,
        selected: true,
        selectable: true
      });
      this.autoMenuItem_ = auto;
      items.push(auto);
      return items;
    }
    /**
     * Group quality levels by lines of resolution
     *
     * @return {Array}
     *         Array of each group
     * @method groupByResolution_
     */
    ;

    _proto.groupByResolution_ = function groupByResolution_() {
      var groups = {};
      var order = [];

      for (var i = 0, l = this.qualityLevels_.length; i < l; i++) {
        var level = this.qualityLevels_[i];
        var active = this.qualityLevels_.selectedIndex === i;
        var lines = level.height;
        var label = void 0;

        if (this.options_.resolutionLabelBitrates) {
          var kbRate = Math.round(level.bitrate / 1000);
          label = lines + "p @ " + kbRate + " kbps";
        } else {
          label = lines + 'p';
        }

        /// XVS custom labels for HLS
        label = this.options_.labels[lines];
        ///

        if (!groups[label]) {
          var subLabel = getSubLabel(lines);
          groups[label] = {
            levels: [],
            label: label,
            controlText: label,
            subLabel: subLabel
          };
          order.push({
            label: label,
            lines: lines
          });
        }

        if (active) {
          groups[label].active = true;
        }

        groups[label].levels.push(i);
      } // Sort from High to Low


      order.sort(function (a, b) {
        return b.lines - a.lines;
      });
      var sortedGroups = [];
      order.forEach(function (group) {
        sortedGroups.push(groups[group.label]);
      });
      return sortedGroups;
    }
    /**
     * Group quality levels by bitrate into SD and HD buckets
     *
     * @return {Array}
     *         Array of each group
     * @method groupByBitrate_
     */
    ;

    _proto.groupByBitrate_ = function groupByBitrate_() {
      // groups[0] for HD, groups[1] for SD, since we want sorting from high to low\
      var groups = [{
        levels: [],
        label: 'HD',
        controlText: 'High Definition'
      }, {
        levels: [],
        label: 'SD',
        controlText: 'Standard Definition'
      }];

      for (var i = 0, l = this.qualityLevels_.length; i < l; i++) {
        var level = this.qualityLevels_[i];
        var active = this.qualityLevels_.selectedIndex === i;
        var group = void 0;

        if (level.bitrate < this.options_.sdBitrateLimit) {
          group = groups[1];
        } else {
          group = groups[0];
        }

        if (active) {
          group.active = true;
        }

        group.levels.push(i);
      }

      if (!groups[0].levels.length || !groups[1].levels.length) {
        // Either HD or SD do not have any quality levels, we should just return an empty
        // list so the ui does not appear when there are no options. We consider 1
        // to be no options since Auto will have the same behavior as selecting the only
        // other option, so it is as effective as not having any options.
        return [];
      }

      return groups;
    }
    /**
     * Handle a change event from the QualityLevelList
     *
     * @method handleQualityChange_
     */
    ;

    _proto.handleQualityChange_ = function handleQualityChange_() {
      var selected = this.qualityLevels_[this.qualityLevels_.selectedIndex];
      var useResolution = this.options_.useResolutionLabels && hasResolutionInfo(this.qualityLevels_);
      var subLabel = '';

      if (selected) {
        if (useResolution) {
          subLabel = getSubLabel(selected.height);
        } else if (selected.bitrate >= this.options_.sdBitrateLimit) {
          subLabel = 'HD';
        }
      }

      if (subLabel === 'HD') {
        this.addClass('vjs-quality-menu-button-HD-flag');
        this.removeClass('vjs-quality-menu-button-4K-flag');
      } else if (subLabel === '4K') {
        this.removeClass('vjs-quality-menu-button-HD-flag');
        this.addClass('vjs-quality-menu-button-4K-flag');
      } else {
        this.removeClass('vjs-quality-menu-button-HD-flag');
        this.removeClass('vjs-quality-menu-button-4K-flag');
      }

      if (this.autoMenuItem_) {
        if (this.autoMenuItem_.manuallySelected_ && selected) {
          // auto mode, update the sub label
          this.autoMenuItem_.subLabel_.innerHTML = this.localize(subLabel);
        } else {
          this.autoMenuItem_.subLabel_.innerHTML = '';
        }
      }
    };

    return QualityMenuButton;
  }(MenuButton);

  videojs.registerComponent('QualityMenuButton', QualityMenuButton);

  var version$1 = "1.4.0";

  var registerPlugin$1 = videojs.registerPlugin || videojs.plugin; // Default options for the plugin.

  var defaults = {
    sdBitrateLimit: 2000000,
    useResolutionLabels: true,
    resolutionLabelBitrates: false,
    defaultResolution: 'none'
  };
  /**
   * Function to invoke when the player is ready.
   *
   * This is a great place for your plugin to initialize itself. When this
   * function is called, the player will have its DOM and child components
   * in place.
   *
   * @function onPlayerReady
   * @param    {Player} player
   *           A Video.js player.
   * @param    {Object} [options={}]
   *           An object of options left to the plugin author to define.
   * @return {Function} disposal function for re initialization
   */

  var onPlayerReady = function onPlayerReady(player, options) {
    player.addClass('vjs-quality-menu');
    var controlBar = player.getChild('controlBar');
    var button = controlBar.addChild('QualityMenuButton', options, controlBar.children_.length - 2);
    return function () {
      player.removeClass('vjs-quality-menu');
      controlBar.removeChild(button);
      button.dispose();
    };
  };
  /**
   * Main entry point for the plugin
   *
   * @function initPlugin
   * @param {Player} player a reference to a videojs Player instance
   * @param {Object} [options] an object with plugin options
   */


  var initPlugin$1 = function initPlugin(player, options) {
    if (typeof player.qualityLevels !== 'undefined') {
      // call qualityLevels to initialize it in case it hasnt been initialized yet
      player.qualityLevels();

      var disposeFn = function disposeFn() {};

      player.ready(function () {
        disposeFn = onPlayerReady(player, options);
        player.on('loadstart', function () {
          disposeFn();
          disposeFn = onPlayerReady(player, options);
        });
      }); // reinitialization is no-op for now

      player.qualityMenu = function () {};

      player.qualityMenu.VERSION = version$1;
    }
  };
  /**
   * A video.js plugin.
   *
   * In the plugin function, the value of `this` is a video.js `Player`
   * instance. You cannot rely on the player being in a "ready" state here,
   * depending on how the plugin is invoked. This may or may not be important
   * to you; if not, remove the wait for "ready"!
   *
   * @function qualityMenu
   * @param    {Object} [options={}]
   *           An object of options left to the plugin author to define.
   */


  var qualityMenu = function qualityMenu(options) {
    initPlugin$1(this, videojs.mergeOptions(defaults, options));
  }; // Register the plugin with video.js.


  registerPlugin$1('qualityMenu', qualityMenu); // Include the version number.

  qualityMenu.VERSION = version$1;

  return qualityMenu;

})));