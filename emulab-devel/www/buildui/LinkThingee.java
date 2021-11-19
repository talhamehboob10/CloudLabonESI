/*
 * Copyright (c) 2002-2006 University of Utah and the Flux Group.
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
import java.awt.*;

public class LinkThingee extends Thingee {
    private Thingee a,b;

    private static Color paleGreen;
    
    static {
	paleGreen = new Color( 0.8f, 1.0f, 0.8f );
    }

    public Thingee getA() { return a; }
    public Thingee getB() { return b; }

    public LinkThingee( String newName, Thingee na, Thingee nb ) {
	super( newName );
	linkable = false;
	moveable = false;
	a = na;
	b = nb;
	super.move((a.getX() + b.getX()) / 2,
	           (a.getY() + b.getY()) / 2 );
    }

    public void move( int nx, int ny ) {
	// nope. can't allow this.
    }

    public void drawIcon( Graphics g ) {
	g.setColor( Color.lightGray );
	g.fillRect( -6, -6, 16, 16 );

	g.setColor( paleGreen );
	g.fillRect( -8, -8, 16, 16 );
 
	g.setColor( Color.black );
	g.drawRect( -8, -8, 16, 16 );	
    }

    public int size() { return 10; }
    /*
    public boolean clicked( int cx, int cy ) {
	return (Math.abs(cx - getX()) < 10 && Math.abs(cy - getY()) < 9);
    }
    */

    public void draw( Graphics g ) {
	super.move((a.getX() + b.getX()) / 2,
	           (a.getY() + b.getY()) / 2 );
	g.setColor( Color.darkGray );
	g.drawLine( a.getX(), a.getY(), b.getX(), b.getY() );
	super.draw( g );
    }

    public Rectangle getRectangle() {
	if (0 == getName().compareTo("")) {
	    return new Rectangle( getX() - 12, getY() - 12, 26, 26 );
	} else {
	    return super.getRectangle();
	}
    }

    public int textDown() { return 20; }

    public boolean isConnectedTo( Thingee t ) {
	return (a == t | b == t);
    }
}
