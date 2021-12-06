/*
 * Copyright (c) 2003-2010 University of Utah and the Flux Group.
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

static const char rcsid[] = "$Id: solution.cc,v 1.15 2009-10-21 20:49:26 tarunp Exp $";

#include "solution.h"
#include "vclass.h"
				 
#include <string>
#include <list>
#include <utility>

#ifdef WITH_XML
#include "annotate_rspec.h"
#include "annotate_rspec_v2.h"
#include "annotate_vtop.h"
#include "xstr.h"
#endif

extern bool ptop_xml_input;
extern bool ptop_rspec_input;

extern bool vtop_xml_input;
extern bool vtop_rspec_input;

extern int rspec_version;

bool both_inputs_rspec = false;
bool both_inputs_xml = false;

#ifdef WITH_XML
	annotate_rspec *rspec_annotater;
	annotate_vtop *vtop_annotater;
#endif

using namespace std;

bool compare_scores(double score1, double score2) {
    if ((score1 < (score2 + ITTY_BITTY)) && (score1 > (score2 - ITTY_BITTY))) {
	return 1;
    } else {
	return 0;
    }
}

/*
 * Print out the current solution
 */
void print_solution(const solution &s) {
    vvertex_iterator vit,veit;
    tb_vnode *vn;

#ifdef WITH_XML
    bool is_generated = false;
    both_inputs_xml = ptop_xml_input && vtop_xml_input;
    both_inputs_rspec = ptop_rspec_input && vtop_rspec_input;
    
    if (both_inputs_rspec == true) {
      switch (rspec_version) {
      case 2:
	rspec_annotater = new annotate_rspec_v2();
	break;
      default:
	rspec_annotater = new annotate_rspec ();
	break;
      }
    }
    else if (both_inputs_xml == true)
      vtop_annotater = new annotate_vtop();
#endif	
    /*
     * Start by printing out all node mappings
     */
    cout << "Nodes:" << endl;
    tie(vit,veit) = vertices(VG);
    for (;vit != veit;++vit) {
      vn = get(vvertex_pmap,*vit);
      if (! s.is_assigned(*vit)) {
        cout << "unassigned: " << vn->name << endl;
      } else {
#ifdef WITH_XML
	string node_name = XStr(vn -> name).c();
	string assigned_to =XStr(get(pvertex_pmap,s.get_assignment(*vit))->name).c();
	if (both_inputs_rspec) {
	  rspec_annotater->annotate_element(node_name.c_str(), assigned_to.c_str());
	  if (rspec_annotater->is_generated_element("node", "virtual_id",
                                              node_name.c_str())) {
	    continue;
    }
	}
	else if (both_inputs_xml) {
	  vtop_annotater->annotate_element(node_name.c_str(), assigned_to.c_str());
	}
#endif
	cout << vn->name << " " 
	     << get(pvertex_pmap,s.get_assignment(*vit))->name << endl;
      }
    }
    cout << "End Nodes" << endl;
    
    /*
     * Next, edges
     */
    cout << "Edges:" << endl;
    vedge_iterator eit,eendit;
    tie(eit,eendit) = edges(VG);
    for (;eit!=eendit;++eit) {
      tb_vlink *vlink = get(vedge_pmap,*eit);

#ifdef WITH_XML
	if (both_inputs_rspec) {
	  is_generated = rspec_annotater->is_generated_element 
	    ("link", "virtual_id", (vlink->name).c_str());
	  if (!is_generated)
	    cout << vlink->name;
	}
	else
	  cout << vlink->name;
#else
	cout << vlink->name;
#endif
		
	list<const char*> links;

	if (vlink->link_info.type_used == tb_link_info::LINK_DIRECT) {
	    // Direct link - just need the source and destination
	    tb_plink *p = get(pedge_pmap,vlink->link_info.plinks.front());
	    tb_plink *p2 = get(pedge_pmap,vlink->link_info.plinks.back());
	    // XXX: This is not correct because it contradicts the comment earlier
	    // It seems that it will work because the front and back of the list will have the same node
	    // But it needs to be checked anyway.
#ifdef WITH_XML
	    if (both_inputs_rspec) {
	      rspec_annotater->annotate_element((vlink->name).c_str(), 
                                          (p->name).c_str());
	      if (is_generated)
		continue;
	    }
	    else if (both_inputs_xml == true) {
	      //	      annotate_vtop((vlink->name).c_str(), (p->name).c_str());
	    }
#endif
	    cout << " direct " << p->name << " (" <<
		p->srcmac << "," << p->dstmac << ") " <<
		p2->name << " (" << p2->srcmac << "," << p2->dstmac << ")";
	} else if (vlink->link_info.type_used ==
		tb_link_info::LINK_INTRASWITCH) {
	    // Intraswitch link - need to grab the plinks to both nodes
	    tb_plink *p = get(pedge_pmap,vlink->link_info.plinks.front());
	    tb_plink *p2 = get(pedge_pmap,vlink->link_info.plinks.back());
#ifdef WITH_XML
	    links.push_back((p->name).c_str());
	    links.push_back((p2->name).c_str());
	    if (both_inputs_rspec) {
	      rspec_annotater->annotate_element((vlink->name).c_str(), &links);
	      if (is_generated)
		continue;
	    }
	    else if (both_inputs_xml) {
	      vtop_annotater->annotate_element((vlink->name).c_str(), &links);
	    }
#endif
	    cout << " intraswitch " << p->name << " (" <<
	      p->srcmac << "," << p->dstmac << ") " <<
	      p2->name << " (" << p2->srcmac << "," << p2->dstmac << ")";
	} else if (vlink->link_info.type_used ==
		   tb_link_info::LINK_INTERSWITCH) {
	  // Interswitch link - iterate through each intermediate link
	  cout << " interswitch ";
	  for (pedge_path::iterator it=vlink->link_info.plinks.begin(); 
	       it != vlink->link_info.plinks.end();
	       ++it) {
	    tb_plink *p = get(pedge_pmap,*it);
#ifdef WITH_XML
	    links.push_back((p->name).c_str());
	    if (!is_generated)
	      cout << " " << p->name 
		   << " (" << p->srcmac << "," << p->dstmac << ")";
#else
	    cout << " " << p->name 
		 << " (" << p->srcmac << "," << p->dstmac << ")";
#endif
	  }
#ifdef WITH_XML
	    if (both_inputs_rspec) {
	      rspec_annotater->annotate_element((vlink->name).c_str(), &links);
	    }
	    else if (both_inputs_xml) {
	      vtop_annotater->annotate_element((vlink->name).c_str(), &links);
	    }
#endif
	} else if (vlink->link_info.type_used == tb_link_info::LINK_TRIVIAL) {
	  // Trivial link - we really don't have useful information to
	  // print, but we'll fake a bunch of output here just to make it
	  // consistent with other (ie. intraswitch) output
	  vvertex vv = vlink->src;
	  tb_vnode *vnode = get(vvertex_pmap,vv);
	  pvertex pv = vnode->assignment;
	  tb_pnode *pnode = get(pvertex_pmap,pv);
#ifdef WITH_XML
	  if (both_inputs_rspec) {
	    rspec_annotater->annotate_element((vlink->name).c_str());
	    if (is_generated)
	      continue;
	  }
#endif
	  cout << " trivial " <<  pnode->name << ":loopback" <<
	    " (" << pnode->name << "/null,(null)) " <<
	    pnode->name << ":loopback" << " (" << pnode->name <<
	    "/null,(null)) ";
	  // TODO: Annotate trivial links in the rspec
	} else {
	  // No mapping at all
	  cout << " Mapping Failed";
	}
	cout << endl;
    }
    cout << "End Edges" << endl;
    cout << "End solution" << endl;
#ifdef WITH_XML
    if (both_inputs_rspec == true) {
      rspec_annotater->cleanup();
    }
#endif
}

/* Print out the current solution and annotate the rspec */
void print_solution (const solution &s, const char* output_filename)
{
  print_solution(s);
#ifdef WITH_XML
  // This will work because print_solution is called already
  // and the objects have been created there
  if (both_inputs_rspec == true) {
      cout << "Writing annotated rspec to " << output_filename << endl;
      rspec_annotater->write_annotated_file (output_filename);
  }
  else if (both_inputs_xml == true) {
      cout << "Writing annotated xml to " << output_filename << endl;
      vtop_annotater->write_annotated_file (output_filename);
  }
#endif
}

/*
 * Print out a summary of the solution - mainly, we print out information from
 * the physical perspective. For example, now many vnodes are assigned to each
 * pnode, and how much total bandwidth each pnode is handling.
 */
void print_solution_summary(const solution &s)
{
  // First, print the number of vnodes on each pnode, and the total number of
  // pnodes used
  cout << "Summary:" << endl;

  // Go through all physical nodes
  int pnodes_used = 0;
  pvertex_iterator pit, pendit;
  tie(pit, pendit) = vertices(PG);
  for (;pit != pendit; pit++) {
    tb_pnode *pnode = get(pvertex_pmap,*pit);

    // We're going to treat switches specially
    bool isswitch = false;
    if (pnode->is_switch) {
      isswitch = true;
    }

    // Only print pnodes we are using, or switches we are going through
    if ((pnode->total_load > 0) ||
	(isswitch && (pnode->switch_used_links > 0))) {

      // What we really want to know is how many PCs, etc. were used, so don't
      // count switches
      if (!pnode->is_switch) {
	pnodes_used++;
      }

      // Print name, number of vnodes, and some bandwidth numbers
      cout << pnode->name << " " << pnode->total_load << " vnodes, " <<
	pnode->nontrivial_bw_used << " nontrivial BW, " <<
	pnode->trivial_bw_used << " trivial BW, type=" << pnode->current_type
	<< endl;

      // Go through all links on this pnode
      poedge_iterator pedge_it,end_pedge_it;
      tie(pedge_it,end_pedge_it) = out_edges(*pit,PG);
      for (;pedge_it!=end_pedge_it;++pedge_it) {
	tb_plink *plink = get(pedge_pmap,*pedge_it);

	tb_pnode *link_dst = get(pvertex_pmap,source(*pedge_it,PG));
	if (link_dst == pnode) {
	  link_dst = get(pvertex_pmap,target(*pedge_it,PG));
	}

	// Ignore links we aren't using
	if ((plink->emulated == 0) && (plink->nonemulated == 0)) {
	  continue;
	}

	// For switches, only print inter-switch links
	if (isswitch && (!link_dst->is_switch)) {
	  continue;
	}
	cout << "    " << plink->bw_used << " " << plink->name << endl;
      }

      // Print out used local additive features
      node_feature_set::iterator feature_it;
      for (feature_it = pnode->features.begin();
	  feature_it != pnode->features.end();++feature_it) {
	if (feature_it->is_local() && feature_it->is_l_additive()) {
	    double total = feature_it->cost();
	    double used = feature_it->used();
	  cout << "    " << feature_it->name() << ": used=" << used <<
	      " total=" << total << endl;
	}
      }
    }
  }
  cout << "Total physical nodes used: " << pnodes_used << endl;

  cout << "End summary" << endl;
}

void pvertex_writer::operator()(ostream &out,const pvertex &p) const {
    tb_pnode *pnode = get(pvertex_pmap,p);
    out << "[label=\"" << pnode->name << "\"";
    fstring style;
    if (pnode->types.find("switch") != pnode->types.end()) {
	out << " style=dashed";
    } else if (pnode->types.find("lan") != pnode->types.end()) {
	out << " style=invis";
    }
    out << "]";
}

void vvertex_writer::operator()(ostream &out,const vvertex &v) const {
    tb_vnode *vnode = get(vvertex_pmap,v);
    out << "[label=\"" << vnode->name << " ";
    if (vnode->vclass == NULL) {
	out << vnode->type;
    } else {
	out << vnode->vclass->get_name();
    }
    out << "\"";
    if (vnode->fixed) {
	out << " style=dashed";
    }
    out << "]";
}

void pedge_writer::operator()(ostream &out,const pedge &p) const {
    out << "[";
    tb_plink *plink = get(pedge_pmap,p);
#ifdef VIZ_LINK_LABELS
    out << "label=\"" << plink->name << " ";
    out << plink->delay_info.bandwidth << "/" <<
	plink->delay_info.delay << "/" << plink->delay_info.loss << "\"";
#endif
    if (plink->is_type == tb_plink::PLINK_INTERSWITCH) {
	out << " style=dashed";
    }
    tb_pnode *src = get(pvertex_pmap,source(p,PG));
    tb_pnode *dst = get(pvertex_pmap,target(p,PG));
    if ((src->types.find("lan") != src->types.end()) ||
	    (dst->types.find("lan") != dst->types.end())) {
	out << " style=invis";
    }
    out << "]";
}

void sedge_writer::operator()(ostream &out,const sedge &s) const {
    tb_slink *slink = get(sedge_pmap,s);
    pedge_writer pwriter;
    pwriter(out,slink->mate);
}

void svertex_writer::operator()(ostream &out,const svertex &s) const {
    tb_switch *snode = get(svertex_pmap,s);
    pvertex_writer pwriter;
    pwriter(out,snode->mate);
}

void vedge_writer::operator()(ostream &out,const vedge &v) const {
    tb_vlink *vlink = get(vedge_pmap,v);
    out << "[";
#ifdef VIZ_LINK_LABELS
    out << "label=\"" << vlink->name << " ";
    out << vlink->delay_info.bandwidth << "/" <<
	vlink->delay_info.delay << "/" << vlink->delay_info.loss << "\"";
#endif
    if (vlink->emulated) {
	out << "style=dashed";
    }
    out <<"]";
}

void graph_writer::operator()(ostream &out) const {
    out << "graph [size=\"1000,1000\" overlap=\"false\" sep=0.1]" << endl;
}

void solution_edge_writer::operator()(ostream &out,const vedge &v) const {
    tb_link_info &linfo = get(vedge_pmap,v)->link_info;
    out << "[";
    string style;
    string color;
    string label;
    switch (linfo.type_used) {
	case tb_link_info::LINK_UNMAPPED: style="dotted";color="red"; break;
	case tb_link_info::LINK_DIRECT: style="dashed";color="black"; break;
	case tb_link_info::LINK_INTRASWITCH:
	    style="solid";color="black";
	    label=get(pvertex_pmap,linfo.switches.front())->name.c_str();
	    break;
	case tb_link_info::LINK_INTERSWITCH:
	    style="solid";color="blue";
	    label="";
	    for (pvertex_list::const_iterator it=linfo.switches.begin();
		    it!=linfo.switches.end();++it) {
		label += get(pvertex_pmap,*it)->name.c_str();
		label += " ";
	    }
	    break;
	case tb_link_info::LINK_TRIVIAL: style="dashed";color="blue"; break;
	case tb_link_info::LINK_DELAYED: style="dotted";color="green"; break;
    }
    out << "style=" << style << " color=" << color;
    if (label.size() != 0) {
	out << " label=\"" << label << "\"";
    }
    out << "]";
}

void solution_vertex_writer::operator()(ostream &out,const vvertex &v) const {
    tb_vnode *vnode = get(vvertex_pmap,v);
    string label = vnode->name.c_str();
    string color;
    if (my_solution.is_assigned(v)) {
	label += " ";
	label += get(pvertex_pmap,my_solution.get_assignment(v))->name.c_str();
	color = "black";
    } else {
	color = "red";
    }
    string style;
    if (vnode->fixed) {
	style="dashed";
    } else {
	style="solid";
    }
    out << "[label=\"" << label << "\" color=" << color <<
	" style=" << style << "]";
}
