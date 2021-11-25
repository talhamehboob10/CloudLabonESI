/*
 * Copyright (c) 2008, 2009 University of Utah and the Flux Group.
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

package protogeni.communication
{
	import flash.utils.Dictionary;

  public class RequestQueue
  {
    public function RequestQueue(shouldPushEvents:Boolean = false) : void
    {
      head = null;
	  nextRequest = null;
      tail = null;
	  pushEvents = shouldPushEvents;
    }

    public function isEmpty() : Boolean
    {
      return head == null;
    }
	
	public function contains(item:*):Boolean
	{
		var parseNode:RequestQueueNode = head;
		if(item is RequestQueueNode)
		{
			while(parseNode != null)
			{
				if(parseNode == item)
					return true;
				parseNode = parseNode.next;
			}
		} else {
			while(parseNode != null)
			{
				if(parseNode.item == item)
					return true;
				parseNode = parseNode.next;
			}
		}
		return false;
	}

    public function push(newItem:*) : void
    {
		var newNode:RequestQueueNode = null;
		var newTail:RequestQueueNode = null;
		
		if(newItem is RequestQueueNode)
		{
			newNode = newItem;
			newTail = newNode;
			while(newTail.next != null)
				newTail = newTail.next;
		}
		else
		{
			newNode = new RequestQueueNode(newItem);
			newTail = newNode;
		}
		
		if (tail != null)
		{
			tail.next = newNode;
			if(nextRequest == null)
				nextRequest = newNode;
		}
		else
		{
			head = newNode;
			nextRequest = newNode;
		}
		
		tail = newTail;
		if(pushEvents)
			Main.protogeniHandler.dispatchQueueChanged();
    }
	
	public function working():Boolean
	{
		return head != null && nextRequest != head;
	}
	
	public function workingCount():int
	{
		var count:int = 0;
		var n:RequestQueueNode = head;
		
		while(n != null && n != nextRequest)
		{
			if((n.item as Request).running)
				count++;
			n = n.next;
		}

		return count;
	}
	
	public function readyToStart():Boolean
	{
		return head != null && nextRequest != null && (nextRequest == head || nextRequest.item.startImmediately == true);
	}

    public function front() : *
    {
      if (head != null)
      {
        return head.item;
      }
      else
      {
        return null;
      }
    }
	
	public function nextAndProgress() : *
	{
		var val:Object = next();
		if(val != null)
			nextRequest = nextRequest.next;
		return val;
	}
	
	public function next() : *
	{
		if (nextRequest != null)
		{
			return nextRequest.item;
		}
		else
		{
			return null;
		}
	}

	/*
    public function pop() : void
    {
      if (head != null)
      {
		if(nextRequest == head)
			nextRequest = head.next;
        head = head.next;
		if(pushEvents)
			Main.protogeniHandler.dispatchQueueChanged();
      }
      if (head == null)
      {
        tail = null;
		nextRequest = null;
      }
    }
	*/
	
	public function getRequestQueueNodeFor(item:Request):RequestQueueNode
	{
		var parseNode:RequestQueueNode = head;
		while(parseNode != null)
		{
			if(parseNode.item == item)
				return parseNode;
			parseNode = parseNode.next;
		}
		return null;
	}
	
	public function remove(removeNode:RequestQueueNode):void
	{
		if(head == removeNode)
		{
			if(nextRequest == head)
				nextRequest = head.next;
			head = head.next;
			if(head == null)
				tail = null;
		} else {
			var previousNode:RequestQueueNode = head;
			var currentNode:RequestQueueNode = head.next;
			while(currentNode != null)
			{
				if(currentNode == removeNode)
				{
					if(nextRequest == currentNode)
						nextRequest = currentNode.next;
					previousNode.next = currentNode.next;
					return;
				}
				previousNode = previousNode.next;
				currentNode = currentNode.next;
			}
		}
		if(pushEvents)
			Main.protogeniHandler.dispatchQueueChanged();
	}

    public var head:RequestQueueNode;
    public var tail:RequestQueueNode;
	public var nextRequest:RequestQueueNode;
	private var pushEvents:Boolean;
  }
}
