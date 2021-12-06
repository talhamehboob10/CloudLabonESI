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
import java.lang.*;

public class IFaceThingee extends Thingee {
    private Thingee a,b;

    private static Color ickyBrown;
    
    static {
	ickyBrown = new Color( 0.8f, 0.8f, 0.7f );
    }

    private void domove() 
    {
	// snap to unit circle from a in dir of b.
	float xd = b.getX() - a.getX();
	float yd = b.getY() - a.getY();
	float magSquared = (xd * xd + yd * yd);
	float mag = 14.0f / (float)Math.sqrt( magSquared );
	
	super.move( (int)((float)a.getX() + (xd * mag)),
		    (int)((float)a.getY() + (yd * mag)));
	/*
	super.move((a.getX() * 3 + b.getX()) / 4,
	           (a.getY() * 3 + b.getY()) / 4 );
	*/
    }

    public IFaceThingee( String newName, Thingee na, Thingee nb ) {
	super( newName );
	linkable = false;
	moveable = false;
	trashable = false;
	a = na;
	b = nb;
	domove();
    }

    public Thingee getA() { return a; }
    public Thingee getB() { return b; }

    public void move( int nx, int ny ) {
	// nope. can't allow this.
    }

    public int size() { return 9; }
    
    public boolean clicked( int cx, int cy ) {
	int x = getX();
	int y = getY();
	return ((cx - x) * (cx - x) + (cy - y) * (cy - y) < (9 * 9));
    }

    public Rectangle getRectangle() {
	return new Rectangle( getX() - 12, getY() - 12, 26, 26 );
    }

    public void drawIcon( Graphics g ) {
	//g.setColor( Color.lightGray );
	//g.fillOval( -6, -6, 16, 16 );

	g.setColor( ickyBrown );
	g.fillOval( -8, -8, 16, 16 );
 
	g.setColor( Color.black );
	g.drawOval( -8, -8, 16, 16 );	
    }

    public void draw( Graphics g ) {
	domove();
	g.setColor( Color.darkGray );
	//g.drawLine( a.getX(), a.getY(), b.getX(), b.getY() );
	super.draw( g );
    }

    public boolean isConnectedTo( Thingee t ) {
	return (a == t | b == t);
    }
}
