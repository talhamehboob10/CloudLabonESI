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

package com.flack.shared.display.components
{
	import com.flack.geni.display.DisplayUtil;
	import com.flack.shared.utils.ViewUtil;
	
	import flash.events.MouseEvent;
	
	import mx.core.DragSource;
	import mx.events.FlexEvent;
	import mx.managers.DragManager;
	
	import spark.components.Button;
	
	public class DataButton extends Button
	{
		[Bindable]
		public var data:*;
		public var dataType:String;
		private var allowDragging:Boolean = false;
		
		private var addedClickHandler:Boolean = false;
		private var addedDragHandlers:Boolean = false;
		
		private var eventTypes:Vector.<String> = new Vector.<String>();
		private var eventFunctions:Vector.<Function> = new Vector.<Function>();
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
			eventTypes.push(type);
			eventFunctions.push(listener);
		}
		
		public function DataButton(newLabel:String,
								   newToolTip:String,
								   img:Class = null,
								   newData:* = null,
								   newDataType:String = "")
		{
			super();
			if(newLabel == null || newLabel.length == 0)
				width = ViewUtil.minComponentWidth;
			else
				label = newLabel;
			toolTip = newToolTip;
			height = ViewUtil.minComponentHeight;
			data = newData;
			if(newData != null)
				addEventListener(MouseEvent.CLICK, click);
			if(img != null)
				setStyle("icon", img);
			if(newDataType != null && newDataType.length > 0)
			{
				dataType = newDataType;
				addEventListener(MouseEvent.MOUSE_MOVE, startDragging);
				addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
				addEventListener(MouseEvent.ROLL_OUT, mouseExit);
			}
			
			addEventListener(FlexEvent.REMOVE, removeHandlers);
		}
		
		private function removeHandlers(e:FlexEvent):void
		{
			while(eventTypes.length > 0)
				removeEventListener(eventTypes.pop(), eventFunctions.pop());
		}
		
		private function click(event:MouseEvent):void
		{
			DisplayUtil.view(event.currentTarget.data);
		}
		
		private function mouseDown(event:MouseEvent):void
		{
			allowDragging = true;
		}
		
		private function mouseExit(event:MouseEvent):void
		{
			allowDragging = false;
		}
		
		private function startDragging(event:MouseEvent):void
		{
			if(allowDragging)
			{
				var ds:DragSource = new DragSource();
				ds.addData(event.currentTarget.data, event.currentTarget.dataType);
				DragManager.doDrag(Button(event.currentTarget), ds, event);
			}
		}
	}
}