package com.flack.geni.resources.virt.extensions.stitching
{
	public final class StitchingDependencyCollection
	{
		public var collection:Vector.<StitchingDependency>;
		public function StitchingDependencyCollection()
		{
			collection = new Vector.<StitchingDependency>();
		}
		
		public function add(s:StitchingDependency):void
		{
			collection.push(s);
		}
		
		public function remove(s:StitchingDependency):void
		{
			var idx:int = collection.indexOf(s);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(s:StitchingDependency):Boolean
		{
			return collection.indexOf(s) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
	}
}