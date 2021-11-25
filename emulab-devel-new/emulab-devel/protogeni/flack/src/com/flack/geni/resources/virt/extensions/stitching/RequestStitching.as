package com.flack.geni.resources.virt.extensions.stitching
{
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.VirtualNode;

	public class RequestStitching
	{
		public var lastUpdateTime:Date;
		public var paths:StitchingPathCollection;
		public var dependencies:StitchingDependencyCollection;
		public function RequestStitching(newLastUpdateTime:Date=null, newPaths:StitchingPathCollection=null)
		{
			lastUpdateTime = newLastUpdateTime;
			if (newPaths != null) {
				paths = newPaths;
			} else {
				paths = new StitchingPathCollection();
			}
			dependencies = new StitchingDependencyCollection();
		}
		
		public function get Managers():GeniManagerCollection
		{
			var managers:GeniManagerCollection = new GeniManagerCollection();
			for each(var path:StitchingPath in paths.collection)
			{
				for each(var hop:StitchingHop in path.hops.collection)
				{
					var hopManager:GeniManager = hop.advertisedLink.manager;
					if(!managers.contains(hopManager))
					{
						managers.add(hopManager);
					}
				}
			}
			return managers;
		}
	}
}