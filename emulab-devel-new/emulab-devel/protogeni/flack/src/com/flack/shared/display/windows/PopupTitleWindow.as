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

package com.flack.shared.display.windows
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.geom.Rectangle;
	
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	import mx.managers.PopUpManager;
	
	import spark.components.TitleWindow;
	import spark.events.TitleWindowBoundsEvent;
	
	public class PopupTitleWindow extends TitleWindow
	{
		public function PopupTitleWindow()
		{
			super();
			addEventListener(CloseEvent.CLOSE, closeWindow);
			addEventListener(TitleWindowBoundsEvent.WINDOW_MOVING, onWindowMoving);
		}
		
		public function onWindowMoving(event:TitleWindowBoundsEvent):void {
			var endBounds:Rectangle = event.afterBounds;
			
			// left edge of the stage
			if (endBounds.x < (endBounds.width*-1 + 48))
				endBounds.x = endBounds.width*-1 + 48;
			
			// right edge of the stage
			if (endBounds.x > (FlexGlobals.topLevelApplication.width - 48))
				endBounds.x = FlexGlobals.topLevelApplication.width - 48;
			
			// top edge of the stage
			if (endBounds.y < 0)
				endBounds.y = 0;
			
			// bottom edge of the stage
			if (endBounds.y > (FlexGlobals.topLevelApplication.height - 48))
				endBounds.y = FlexGlobals.topLevelApplication.height - 48;
		}
		
		public function showWindow(center:Boolean = true, modal:Boolean = false):void
		{
			if(!isPopUp)
				PopUpManager.addPopUp(this, FlexGlobals.topLevelApplication as DisplayObject, modal);
			else
				PopUpManager.bringToFront(this);
			if(center)
				PopUpManager.centerPopUp(this);
		}
		
		public function closeWindow(event:Event = null):void
		{
			cleanup();
			PopUpManager.removePopUp(this);
		}
		
		public function cleanup():void {
			removeEventListener(CloseEvent.CLOSE, closeWindow);
			removeEventListener(TitleWindowBoundsEvent.WINDOW_MOVING, onWindowMoving);
		}
	}
}