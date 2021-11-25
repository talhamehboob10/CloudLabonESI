/*
 * Copyright (c) 2006-2007 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

import java.util.Vector;

public interface DataSource {
    
    /**
     * Get all possible "sources."  A source is a grouping of measurement 
     * "sets."
     */
    public String[] getSources();

    /**
     * Get all known sets for the specified source.
     */
    public String[] getSourceSetList(String src);
    
    /**
     * Refresh sources so that getSources() always returns the most recent list.
     */
    public void refreshSources();
    
    /**
     * Download the dataset.
     */
    public Dataset fetchData(String Source,String set);
    
    
}
