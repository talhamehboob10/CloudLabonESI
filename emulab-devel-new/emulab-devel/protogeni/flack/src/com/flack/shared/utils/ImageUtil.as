/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */
 
 package com.flack.shared.utils
{
	import spark.primitives.BitmapImage;

	/**
	 * Common images/functions used for icons around the library
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ImageUtil
	{
		public static function getBitmapImageFor(img:Class):BitmapImage
		{
			var newBitmapImage:BitmapImage = new BitmapImage();
			newBitmapImage.source = img;
			return newBitmapImage;
		}
		
		[Bindable]
		[Embed(source="../../../../../images/flack.png")]
		public static var logoIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/chart_bar.png")]
		public static var statisticsIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/document_signature.png")]
		public static var credentialIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/information.png")]
		public static var infoIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/help.png")]
		public static var helpIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_left.png")]
		public static var leftIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_right.png")]
		public static var rightIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_up.png")]
		public static var upIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_down.png")]
		public static var downIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/status_online.png")]
		public static var userIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/status_offline.png")]
		public static var noUserIcon:Class;
		
		[Bindable]
        [Embed(source="../../../../../images/tick.png")]
        public static var availableIcon:Class;

        [Bindable]
        [Embed(source="../../../../../images/cross.png")]
        public static var crossIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/administrator.png")]
        public static var ownedIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/server.png")]
		public static var exclusiveIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/server_stanchion.png")]
		public static var sharedIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/computer.png")]
		public static var rawIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/layers.png")]
		public static var vmIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/link.png")]
        public static var linkIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/router.png")]
		public static var lanIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/flag_green.png")]
        public static var flagGreenIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/flag_red.png")]
        public static var flagRedIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/flag_yellow.png")]
        public static var flagYellowIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/flag_orange.png")]
        public static var flagOrangeIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/exclamation.png")]
        public static var errorIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/error.png")]
		public static var warningIcon:Class;
        
        [Bindable]
        [Embed(source="../../../../../images/exclamation.png")]
        public static var exclamationIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/lightbulb.png")]
		public static var onIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/lightbulb_off.png")]
		public static var offIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/add.png")]
		public static var addIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/cancel.png")]
		public static var cancelIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/stop.png")]
		public static var stopIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/control_stop_blue.png")]
		public static var stopControlIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/control_pause_blue.png")]
		public static var pauseControlIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/control_play_blue.png")]
		public static var playControlIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/control_repeat_blue.png")]
		public static var repeatControlIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/delete.png")]
		public static var deleteIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_refresh.png")]
		public static var refreshIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/map.png")]
		public static var mapIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/graph.png")]
		public static var graphIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page.png")]
		public static var pageIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page_code.png")]
		public static var pageCodeIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page_white.png")]
		public static var pageWhiteIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page_white_code.png")]
		public static var pageWhiteCodeIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/wand.png")]
		public static var actionIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/ssl_certificates.png")]
		public static var sslIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/keyboard.png")]
		public static var keyboardIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/system_monitor.png")]
		public static var consoleIcon:Class;
		
		// Entities
		
		[Bindable]
		[Embed(source="../../../../../images/entity.png")]
		public static var authorityIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/building.png")]
		public static var managerIcon:Class;
		
		// Operations
		
		[Bindable]
		[Embed(source="../../../../../images/find.png")]
		public static var findIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/magnifier.png")]
		public static var searchIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/disk.png")]
		public static var saveIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/folder.png")]
		public static var openIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/paste_plain.png")]
		public static var pasteIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page_white_copy.png")]
		public static var copyIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/key.png")]
		public static var keyIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/shield.png")]
		public static var authenticationIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/draw_eraser.png")]
		public static var eraseIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/email.png")]
		public static var emailIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/time.png")]
		public static var timeIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/world.png")]
		public static var worldIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/lightning.png")]
		public static var lightningIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/chart_bar.png")]
		public static var barchartIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page_white_code.png")]
		public static var advertisementIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/page_code.png")]
		public static var manifestIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/plugin.png")]
		public static var pluginIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/gear_in.png")]
		public static var settingsIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/resources.png")]
		public static var resourcesIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/document_inspector.png")]
		public static var previewIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_undo.png")]
		public static var undoIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/arrow_redo.png")]
		public static var redoIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/stamp_pattern.png")]
		public static var cloneIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/download.png")]
		public static var importIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/brick.png")]
		public static var extensionIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/bricks.png")]
		public static var extensionsIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/control_panel.png")]
		public static var dashboardIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/legend.png")]
		public static var listIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/firewall.png")]
		public static var firewallIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/hostname.png")]
		public static var hostnameIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/title_window.png")]
		public static var windowIcon:Class;
		
		[Bindable]
		[Embed(source="../../../../../images/bullet_arrow_down.png")]
		public static var bulletDownIcon:Class;
	}
}