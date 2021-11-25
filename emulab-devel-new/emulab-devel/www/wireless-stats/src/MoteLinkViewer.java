/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.util.*;

//class ImageObserverImpl implements java.awt.image.ImageObserver {
//    public boolean updateImage(Image img, int infoflags, int x, int y, int width, int height) {
//        System.out.println("w = "+width+",h = "+height);
//    }
//}

public class MoteLinkViewer extends javax.swing.JFrame {

    private Hashtable datasets;
    
    public MoteLinkViewer(Dataset[] sets) {
        this.datasets = new Hashtable();
        
        for (int i = 0; i < sets.length; ++i) {
            java.awt.image.ImageObserver io;
            java.awt.Image bgImage;
            
            io = new java.awt.Component() {
                public boolean updateImage(Image img, int infoflags, int x, int y, int width, int height) {
                    System.out.println("w = "+width+",h = "+height);

                    return true;
                }
            };
            
            sets[i].addFloor(0);
            sets[i].addScale(1);
            Image ti = Toolkit.getDefaultToolkit().getImage(sets[i].image_path);
            sets[i].addImage(ti,0,1);
            
            try {
                MediaTracker tracker = new MediaTracker(this);
                tracker.addImage(ti, 0);
                tracker.waitForID(0);
                //System.out.println("width = "+bgImage.getWidth(io));
            }
            catch (InterruptedException ex) {
                ex.printStackTrace();
            }
            
            // in the applet, we'll read in the possible datasets and 
            try {
                sets[i].data = GenericStats.parseDumpFile(sets[i].dataFile);
                sets[i].positions = NodePositions.parseFile(sets[i].positionFile);

                sets[i].model = new MapDataModel(sets[i]);
                datasets.put(sets[i].name,sets[i]);
            }
            catch (Exception e) {
                e.printStackTrace();
                System.exit(-2);
            }
        }
        
        initComponents();
        
    }
    
    // <editor-fold defaultstate="collapsed" desc=" Generated Code ">//GEN-BEGIN:initComponents
    private void initComponents() {
        java.awt.GridBagConstraints gridBagConstraints;

        nodeMapScrollPane = new javax.swing.JScrollPane();
        nodeMapPanel = new NodeMapPanel();
        //nodeMapPanel.setBackgroundImage(bgImage);
        //nodeMapPanel.setPositions(positions);
        //nodeMapPanel.setILEStats(model);
        controlPanel = new ControlPanel(datasets,nodeMapPanel);

        getContentPane().setLayout(new java.awt.GridBagLayout());

        setDefaultCloseOperation(javax.swing.WindowConstants.EXIT_ON_CLOSE);
        nodeMapScrollPane.setBackground(new java.awt.Color(255, 255, 255));
        nodeMapScrollPane.setViewportView(nodeMapPanel);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.BOTH;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.weighty = 1.0;
        getContentPane().add(nodeMapScrollPane, gridBagConstraints);

        controlPanel.setPreferredSize(new java.awt.Dimension(200, 247));
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.fill = java.awt.GridBagConstraints.VERTICAL;
        getContentPane().add(controlPanel, gridBagConstraints);

        pack();
    }// </editor-fold>//GEN-END:initComponents
        
    public static void main(final String args[]) {
        int floor;
        float ppm;
        String name,positionFile,dataFile,image_path,building;
        
        Vector dsaV = new Vector();
        
        for (int i = 0; i < args.length; ++i) {
            String[] aa = args[i].split(",");
            if (aa.length == 7) {
                name = aa[0];
                positionFile = aa[1];
                dataFile = aa[2];
                building = aa[3];
                floor = Integer.parseInt(aa[4]);
                image_path = aa[5];
                ppm = Float.parseFloat(aa[6]);
                
                dsaV.add(new Dataset(name,positionFile,dataFile,building,floor,image_path,ppm));
            }
        }
        
        final Dataset[] dsa = new Dataset[dsaV.size()];
        int i = 0;
        for (Enumeration e1 = dsaV.elements(); e1.hasMoreElements(); ) {
            dsa[i++] = (Dataset)e1.nextElement();
        }
        
        java.awt.EventQueue.invokeLater(new Runnable() {
            public void run() {
                new MoteLinkViewer(dsa).setVisible(true);
            }
        });
    }
    
    // Variables declaration - do not modify//GEN-BEGIN:variables
    private ControlPanel controlPanel;
    private NodeMapPanel nodeMapPanel;
    private javax.swing.JScrollPane nodeMapScrollPane;
    // End of variables declaration//GEN-END:variables
    
}
