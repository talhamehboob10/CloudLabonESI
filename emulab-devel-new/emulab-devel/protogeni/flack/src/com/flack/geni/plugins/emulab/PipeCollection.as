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

package com.flack.geni.plugins.emulab
{
	import com.flack.geni.resources.virt.VirtualInterface;

	/**
	 * Collection of pipes
	 * @author mstrum
	 * 
	 */
	public class PipeCollection
	{
		public var collection:Vector.<Pipe>;
		public function PipeCollection()
		{
			collection = new Vector.<Pipe>();
		}
		
		public function add(p:Pipe):void
		{
			collection.push(p);
		}
		
		public function remove(p:Pipe):void
		{
			var idx:int = collection.indexOf(p);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param source Source interface
		 * @param destination Destination interface
		 * @return Pipe matching the parameters
		 * 
		 */
		public function getFor(source:VirtualInterface, destination:VirtualInterface):Pipe
		{
			for each(var pipe:Pipe in collection)
			{
				if(pipe.src == source && pipe.dst == destination)
					return pipe;
			}
			return null;
		}
		
		/**
		 * 
		 * @param source Source interface
		 * @return Pipes with the given source
		 * 
		 */
		public function getForSource(source:VirtualInterface):PipeCollection
		{
			var result:PipeCollection = new PipeCollection();
			for each(var pipe:Pipe in collection)
			{
				if(pipe.src == source)
					result.add(pipe);
			}
			return result;
		}
		
		/**
		 * 
		 * @param destination Destination interface
		 * @return Pipes with the given destination
		 * 
		 */
		public function getForDestination(destination:VirtualInterface):PipeCollection
		{
			var result:PipeCollection = new PipeCollection();
			for each(var pipe:Pipe in collection)
			{
				if(pipe.dst == destination)
					result.add(pipe);
			}
			return result;
		}
		
		/**
		 * 
		 * @param test Interface
		 * @return Pipes with the source or destination as the given interface
		 * 
		 */
		public function getForAny(test:VirtualInterface):PipeCollection
		{
			var result:PipeCollection = new PipeCollection();
			for each(var pipe:Pipe in collection)
			{
				if(pipe.dst == test || pipe.src == test)
					result.add(pipe);
			}
			return result;
		}
	}
}