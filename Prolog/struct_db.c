#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <limits.h>
#ifdef _GNU_PROLOG
    #include "gprolog.h"
    #define FORPROL Bool
    #define FAIL return(FALSE)
    #define SUCCEED return(TRUE)
#else
    #include "sicstus/sicstus.h"
    #define FORPROL void
    #define FAIL {SP_fail();return;}
    #define SUCCEED return
#endif

#define EXISTS 128
#define HIDDEN 1

typedef struct id_list_t {
  unsigned short me;
  struct id_list_t *next;
} id_list;

id_list id_lists[4*USHRT_MAX];
int next_id_list = 0;
int rootAtom;
  
typedef struct node_t {
  int id_atom;
  int nclass;
  unsigned short parent;
  id_list *children;
  id_list *arcs_to;
  id_list *arcs_from;
  int l,t,r,b;
  int il,it,ir,ib;
  unsigned char hide;
  int offx, offy;
  int cx, cy;
} node;
    
typedef struct arc_t {
  int id_atom;
  int aclass;
  int dest;
  int source;
  unsigned short prev;
  id_list *subs;
  id_list *arcs_to;
  id_list *arcs_from;
  int offx, offy;
  int xk, yb;
} arc;
    
node nodes[USHRT_MAX];
arc arcs[USHRT_MAX];
id_list* roots;
/*
intptr_t usedBits = 0;
void* safe_malloc(int count) {
  intptr_t ptr;

  ptr = (intptr_t)malloc(count);
  if (ptr & ~usedBits) {
    usedBits = usedBits|ptr;
    printf("debug_c malloc uses new bits, mask now %lx\n", usedBits);
  }
  return (void*)ptr;
}
*/
FORPROL empty_tree(PlTerm ushrtmx) {
  int count;
  for (count=0; count<USHRT_MAX; ++count) {
    nodes[count].hide = 0;
    arcs[count].id_atom = 0;
  }
  for (count=0; count<4*USHRT_MAX; ++count) {
    id_lists[count].me = USHRT_MAX;
  }
  roots = NULL;
  rootAtom = Pl_Create_Atom("root");
  return Pl_Un_Positive(USHRT_MAX, ushrtmx);
}

id_list* alloc_id_list() {
  while (id_lists[next_id_list].me != USHRT_MAX)
    if (++next_id_list == 4*USHRT_MAX)
      next_id_list = 0;
  return id_lists + next_id_list;
}

void free_id_list(id_list* to_free) {
  to_free->me = USHRT_MAX;
}

unsigned short get_number(char* nodeId) {
  return atoi(nodeId+4);
}

unsigned short get_arc_number(char* nodeId) {
  return atoi(nodeId+3);
}

void add_to_list(id_list** tgt, short int newId) {
  id_list *newItem;

  newItem = alloc_id_list();
  newItem->me = newId;
  newItem->next = *tgt;
  *tgt = newItem;
}

void add_node_to_list(id_list** tgt, char* newId) {
  add_to_list(tgt, get_number(newId));
}

void add_arc_to_list(id_list** tgt, char* newId) {
  add_to_list(tgt, get_arc_number(newId));
}

void remove_from_list(id_list** tgt, short int oldId) {
  id_list *here;

  here = *tgt;
  if (here) {
    remove_from_list(&(here->next), oldId);
    
    if (oldId == here->me) {
      *tgt = here->next;
      free_id_list(here); 
    }
  }
}
    
int is_node(char* node) {
  return !strncmp(node, "node", 4);
}

int is_arc(char* node) {
  return !strncmp(node, "arc", 3);
}

void remove_node_from_list(id_list** tgt, char* oldId) {
  remove_from_list(tgt, get_number(oldId));
}

void remove_arc_from_list(id_list** tgt, char* oldId) {
  remove_from_list(tgt, get_arc_number(oldId));
}

FORPROL create_node(PlTerm newnode) {
  node *childNode;
  int childAtom;
  
  childAtom = Pl_Rd_Atom(newnode);
  childNode = &(nodes[get_number(Pl_Atom_Name(childAtom))]);
  childNode->id_atom = childAtom;
  childNode->nclass = 0;
  childNode->children = NULL;
  childNode->arcs_to = NULL;
  childNode->arcs_from = NULL;
  childNode->b = INT_MIN;
  childNode->ib = INT_MIN;
  childNode->hide = EXISTS;
  childNode->offy = INT_MIN;
  childNode->cy = INT_MIN;
  SUCCEED;
}
  
FORPROL add_to_tree(PlTerm parent, PlTerm child) {
  int parentAtom;
  unsigned short parentNum;
  node *childNode, *parentNode;
  char* childStr;

  parentAtom = Pl_Rd_Atom(parent);
  childStr = Pl_Atom_Name(Pl_Rd_Atom(child));
  childNode = &(nodes[get_number(childStr)]);

  if (parentAtom != rootAtom) {
    childNode->parent = get_number(Pl_Atom_Name(parentAtom));
    parentNode = &(nodes[childNode->parent]);
    add_node_to_list(&(parentNode->children), childStr);
  } else {
    childNode->parent = USHRT_MAX;
    add_node_to_list(&roots, childStr);
  }
  SUCCEED;
}

// just to shorten the code...
node* node_from_term(PlTerm term) {
  return  &(nodes[get_number(Pl_Atom_Name(Pl_Rd_Atom(term)))]);
}

FORPROL set_class(PlTerm cNode, PlTerm cClass) {
  //  printf("debug_c Set class of %s to %d\n", cNode, cClass);
  node_from_term(cNode)->nclass = Pl_Rd_Atom(cClass);
  SUCCEED;
}

FORPROL add_bbox(PlTerm parent, PlTerm l, PlTerm t, PlTerm r, PlTerm b) {
  node *parentNode;

  parentNode = node_from_term(parent);
  parentNode->l = (int)Pl_Rd_Integer(l);
  parentNode->t = (int)Pl_Rd_Integer(t);
  parentNode->r = (int)Pl_Rd_Integer(r);
  parentNode->b = (int)Pl_Rd_Integer(b);
  SUCCEED;
}

FORPROL add_iext(PlTerm parent, PlTerm il, PlTerm it, PlTerm ir, PlTerm ib) {
  node *parentNode;

  parentNode = node_from_term(parent);
  parentNode->il = (int)Pl_Rd_Integer(il);
  parentNode->it = (int)Pl_Rd_Integer(it);
  parentNode->ir = (int)Pl_Rd_Integer(ir);
  parentNode->ib = (int)Pl_Rd_Integer(ib);
  SUCCEED;
}

FORPROL add_capt_off(PlTerm parent, PlTerm offx, PlTerm offy) {
  node *Node;
  arc *Arc;
  char* atomStr;
  
  if (is_arc(atomStr = Pl_Atom_Name(Pl_Rd_Atom(parent)))) {
    Arc = &(arcs[get_arc_number(atomStr)]);
    Arc->offx = (int)Pl_Rd_Integer(offx);
    Arc->offy = (int)Pl_Rd_Integer(offy);
  } else {
    Node =  &(nodes[get_number(atomStr)]);
    Node->offx = (int)Pl_Rd_Integer(offx);
    Node->offy = (int)Pl_Rd_Integer(offy);
  }
  SUCCEED;
}

FORPROL add_centre(PlTerm parent, PlTerm cx, PlTerm cy) {
  node *parentNode;

  parentNode = node_from_term(parent);
  parentNode->cx = (int)Pl_Rd_Integer(cx);
  parentNode->cy = (int)Pl_Rd_Integer(cy);
  SUCCEED;
}

FORPROL set_hidden(PlTerm parent, PlTerm whether) {
  unsigned char* hid_reg;

  hid_reg = &(node_from_term(parent)->hide);
  if (Pl_Rd_Integer(whether))
    *hid_reg = *hid_reg | HIDDEN;
  else
    *hid_reg = *hid_reg & ~HIDDEN;
  SUCCEED;
}

FORPROL create_arc(PlTerm newlink) {
  arc *newArc;
  int childAtom;
  
  childAtom = Pl_Rd_Atom(newlink);
  newArc = &(arcs[get_arc_number(Pl_Atom_Name(childAtom))]);
  newArc->id_atom = childAtom;
  newArc->aclass = 0;
  newArc->prev = USHRT_MAX;
  newArc->subs = NULL;
  newArc->arcs_to = NULL;
  newArc->arcs_from = NULL;
  newArc->yb = INT_MIN;
  newArc->offy = INT_MIN;
  SUCCEED;
}

FORPROL add_link(PlTerm dest, PlTerm source, PlTerm link) {
  arc *newArc;
  id_list** end_pts;
  char* endName;
  char* linkName;

  linkName = Pl_Atom_Name(Pl_Rd_Atom(link));
  newArc = &(arcs[get_arc_number(linkName)]);
  newArc->source = Pl_Rd_Atom(source);
  newArc->dest = Pl_Rd_Atom(dest);

  endName = Pl_Atom_Name(newArc->dest);
  if (is_arc(endName))
    end_pts = &(arcs[get_arc_number(endName)].arcs_to);
  else 
    end_pts = &(nodes[get_number(endName)].arcs_to);
  add_arc_to_list(end_pts, linkName);

  endName = Pl_Atom_Name(newArc->source);
  if (is_arc(endName))
    end_pts = &(arcs[get_arc_number(endName)].arcs_from);
  else 
    end_pts = &(nodes[get_number(endName)].arcs_from);
  add_arc_to_list(end_pts, linkName);
  SUCCEED;
}

FORPROL add_continuation(PlTerm before, PlTerm after) {
  arc *Arc;
  char* afterName;

  afterName = Pl_Atom_Name(Pl_Rd_Atom(after));
  Arc = &(arcs[get_arc_number(afterName)]);
  Arc->prev = get_arc_number(Pl_Atom_Name(Pl_Rd_Atom(before)));
  Arc = &(arcs[Arc->prev]);
  add_arc_to_list(&(Arc->subs), afterName);
  SUCCEED;
}

// just to shorten the code...
arc* arc_from_term(PlTerm term) {
  return  &(arcs[get_arc_number(Pl_Atom_Name(Pl_Rd_Atom(term)))]);
}

FORPROL set_type(PlTerm cArc, PlTerm cType) {
  arc_from_term(cArc)->aclass = Pl_Rd_Atom(cType);
  SUCCEED;
}

FORPROL add_curve(PlTerm parent, PlTerm xk, PlTerm yb) {
  arc *parentArc;

  parentArc = arc_from_term(parent);
  parentArc->xk = (int)Pl_Rd_Integer(xk);
  parentArc->yb = (int)Pl_Rd_Integer(yb);
  SUCCEED;
}


FORPROL delete_node(PlTerm oldcomp) {
  node_from_term(oldcomp)->hide = 0;
  SUCCEED;
}

FORPROL remove_from_tree(PlTerm parent, PlTerm child) {
  node* parentNode;
  int parentAtom;
  char* childStr;

  // no need to clear parent field in child, it will get another soon
  parentAtom = Pl_Rd_Atom(parent);
  childStr = Pl_Atom_Name(Pl_Rd_Atom(child));

  if (parentAtom != rootAtom) {
    parentNode = &(nodes[get_number(Pl_Atom_Name(parentAtom))]);
    remove_node_from_list(&(parentNode->children), childStr);
  } else {
    remove_node_from_list(&roots, childStr);
  }
  SUCCEED;
}

FORPROL unset_class(PlTerm cNode) {
  node_from_term(cNode)->nclass = 0;
  SUCCEED;
}

FORPROL remove_bbox(PlTerm parent) {
  node_from_term(parent)->b = INT_MIN;
  SUCCEED;
}
  
FORPROL remove_iext(PlTerm parent) {
  node_from_term(parent)->ib = INT_MIN;
  SUCCEED;
}
  
FORPROL remove_centre(PlTerm parent) {
  node_from_term(parent)->cy = INT_MIN;
  SUCCEED;
}
  
FORPROL remove_capt_off(PlTerm parent) {
  char* parentStr;

  parentStr = Pl_Atom_Name(Pl_Rd_Atom(parent));
  if (is_arc(parentStr))
    arcs[get_arc_number(parentStr)].offy = INT_MIN;
  else
    nodes[get_number(parentStr)].offy = INT_MIN;
  SUCCEED;
}

FORPROL delete_arc(PlTerm oldlink) {
  arc_from_term(oldlink)->id_atom = 0;
  SUCCEED;
}

FORPROL remove_link(PlTerm dest, PlTerm source, PlTerm link) {
  id_list** end_pts;
  char* linkName;
  char* endName;

  linkName = Pl_Atom_Name(Pl_Rd_Atom(link));
  endName = Pl_Atom_Name(Pl_Rd_Atom(dest));
  if (is_arc(endName))
    end_pts = &(arcs[get_arc_number(endName)].arcs_to);
  else 
    end_pts = &(nodes[get_number(endName)].arcs_to);
  remove_arc_from_list(end_pts, linkName);

  endName = Pl_Atom_Name(Pl_Rd_Atom(source));
  if (is_arc(endName))
    end_pts = &(arcs[get_arc_number(endName)].arcs_from);
  else 
    end_pts = &(nodes[get_number(endName)].arcs_from);
  remove_arc_from_list(end_pts, linkName);
  SUCCEED;
}

FORPROL unset_type(PlTerm oldlink) {
  arc_from_term(oldlink)->aclass = 0;
  SUCCEED;
}

FORPROL remove_continuation(PlTerm before, PlTerm after) {
  char* afterStr;

  afterStr = Pl_Atom_Name(Pl_Rd_Atom(after));
  arcs[get_arc_number(afterStr)].prev = USHRT_MAX;
  remove_arc_from_list(&(arc_from_term(before)->subs), afterStr);
  SUCCEED;
}

FORPROL remove_curve(PlTerm parent) {
  arc_from_term(parent)->yb = INT_MIN;
  SUCCEED;
}


int node_exists(node* it) {
  return (it->hide & EXISTS);
}

int arc_exists(arc* it) {
  return it->id_atom;
}

FORPROL find_parent(PlTerm child, PlTerm parent) {
  node* childNode;
  char* childStr;

  childStr = Pl_Atom_Name(Pl_Rd_Atom(child));

  if (!is_node(childStr))
    FAIL;
  childNode = &(nodes[get_number(childStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  return Pl_Un_Atom(nodes[childNode->parent].id_atom, parent);
}

// need to make a list so unification is all or nothing
PlBool list_box_ints(intptr_t l, intptr_t t, intptr_t r, intptr_t b, PlTerm tgt)
{
  PlTerm ints[4];

  ints[0] = Pl_Mk_Integer(l);
  ints[1] = Pl_Mk_Integer(t);
  ints[2] = Pl_Mk_Integer(r);
  ints[3] = Pl_Mk_Integer(b);

  return Pl_Un_Proper_List(4, ints, tgt);
}

PlBool list_vect_ints(intptr_t x, intptr_t y, PlTerm tgt)
{
  PlTerm ints[2];

  ints[0] = Pl_Mk_Integer(x);
  ints[1] = Pl_Mk_Integer(y);

  return Pl_Un_Proper_List(2, ints, tgt);
}

FORPROL find_bbox(PlTerm child, PlTerm result) {
  node* childNode;
  char* childStr;

  childStr = Pl_Atom_Name(Pl_Rd_Atom(child));
  if (!is_node(childStr))
    FAIL;
  childNode = &(nodes[get_number(childStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  if (childNode->b == INT_MIN)
    FAIL;
  return list_box_ints(childNode->l, childNode->t, childNode->r, childNode->b, 
		       result);
}

FORPROL find_iext(PlTerm child, PlTerm result) {
  node* childNode;
  char* childStr;

  childStr = Pl_Atom_Name(Pl_Rd_Atom(child));
  if (!is_node(childStr))
    FAIL;
  childNode = &(nodes[get_number(childStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  if (childNode->ib == INT_MIN)
    FAIL;
  return list_box_ints(childNode->il, childNode->it, 
		       childNode->ir, childNode->ib, result);
}

FORPROL find_capt_off(PlTerm comp, PlTerm result) {
  node *Node;
  arc *Arc;
  char* compStr;
  
  compStr = Pl_Atom_Name(Pl_Rd_Atom(comp));
  if (is_arc(compStr)) {
    Arc = &(arcs[get_arc_number(compStr)]);
    if (!arc_exists(Arc)) 
      FAIL;
    if (Arc->offy == INT_MIN)
      FAIL;
    return list_vect_ints(Arc->offx, Arc->offy, result);
  } else if (is_node(compStr)) {
    Node = &(nodes[get_number(compStr)]);
    if (!node_exists(Node)) 
      FAIL;
    if (Node->offy == INT_MIN)
      FAIL;
    return list_vect_ints(Node->offx, Node->offy, result);
  } else
      FAIL;
}

FORPROL find_centre(PlTerm child, PlTerm result) {
  node* childNode;
  char* nodeStr;

  nodeStr = Pl_Atom_Name(Pl_Rd_Atom(child));
  if (!is_node(nodeStr))
    FAIL;
  childNode = &(nodes[get_number(nodeStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  if (childNode->cy == INT_MIN)
    FAIL;
  return list_vect_ints(childNode->cx, childNode->cy, result);
}

FORPROL is_hidden(PlTerm parent) {
  node* parentNode;
  char* parentStr;

  parentStr = Pl_Atom_Name(Pl_Rd_Atom(parent));
  if (!is_node(parentStr))
    FAIL;
  parentNode = &(nodes[get_number(parentStr)]);
  if (!node_exists(parentNode)) 
    FAIL;
  if (parentNode->hide & HIDDEN)
    SUCCEED;
  FAIL;
}

FORPROL find_curve(PlTerm link, PlTerm result) {
  arc* childArc;
  char* arcStr;

  arcStr = Pl_Atom_Name(Pl_Rd_Atom(link));
  if (!is_arc(arcStr))
    FAIL;
  childArc = &(arcs[get_arc_number(arcStr)]);
  if (!arc_exists(childArc)) 
    FAIL;
  if (childArc->yb == INT_MIN)
    FAIL;
  return list_vect_ints(childArc->xk, childArc->yb, result);
}
/* 
FORPROL find_child(char* parent, char** child) {
  id_list *p;

  if (Get_Choice_Counter() == 0) {        // first invocation ?
    if (!strcmp(parent, "root"))
      p = roots;
    else if (!is_node(parent))
      p = NULL;
    else
      p = nodes[get_number(parent)]->children;
  
    if (!p) {
      No_More_Choice();                      // remove choice-point
      FAIL;
    }
  } else
    p = NULL;

  return run_through_list(p, child);
}
*/
FORPROL get_child_list_pointer(PlTerm parent, PlTerm ptr) {
  int parentAtom;
  id_list* result;

  parentAtom = Pl_Rd_Atom(parent);
  if (parentAtom == rootAtom)
    result = roots;
  else {
    char* parentStr;
    parentStr = Pl_Atom_Name(parentAtom);
    if (is_node(parentStr))
      result = nodes[get_number(parentStr)].children;
    else
      result = NULL;
  }
  return Pl_Un_Positive((uintptr_t)result, ptr);
}
/*
This used the nondeterministic features of the interface, but too complicated
and not portable. Easier to let Prolog decide whether to retry...

FORPROL run_through_list(id_list* p, char** result) {
  id_list **info_pos;

  info_pos = Get_Choice_Buffer(id_list **); // recover the buffer 
  if (!p)
    p = *info_pos;

  if (p) {
    *info_pos = p->next;
    if (!*info_pos)                      // C does not appear again
      No_More_Choice();                  // remove choice-point

*result = p->me;                      // set the output argument
SUCCEED;                         // succeed
  }
  No_More_Choice();                      // remove choice-point
  FAIL;
}
*/
FORPROL get_node_and_next_ptr(PlTerm oldptr, PlTerm result, PlTerm newptr) {
  id_list* realPtr;
  
  realPtr = (id_list*)Pl_Rd_Positive(oldptr);
  Pl_Un_Positive((uintptr_t)(realPtr->next), newptr); // always succeed
  return Pl_Un_Atom(nodes[realPtr->me].id_atom, result);
}

FORPROL get_arc_and_next_ptr(PlTerm oldptr, PlTerm result, PlTerm newptr) {
  id_list* realPtr;
  
  realPtr = (id_list*)Pl_Rd_Positive(oldptr);
  Pl_Un_Positive((uintptr_t)(realPtr->next), newptr); // always succeed
  return Pl_Un_Atom(arcs[realPtr->me].id_atom, result);
}

FORPROL find_ends(PlTerm link, PlTerm source, PlTerm dest) {
  arc* thisLink;
  char* linkName;

  linkName = Pl_Atom_Name(Pl_Rd_Atom(link));
  if (!is_arc(linkName))
    FAIL;
  thisLink = &(arcs[get_arc_number(linkName)]);
  if (!arc_exists(thisLink)) 
    FAIL;
  if (!Pl_Un_Atom(thisLink->source, source)) 
    FAIL;
  if (!Pl_Un_Atom(thisLink->dest, dest)) 
    FAIL;
  SUCCEED;
}

FORPROL find_prev(PlTerm link, PlTerm prev) {
  arc* thisLink;
  char* linkName;

  linkName = Pl_Atom_Name(Pl_Rd_Atom(link));
  if (!is_arc(linkName))
    FAIL;
  thisLink = &(arcs[get_arc_number(linkName)]);
  if (!arc_exists(thisLink)) 
    FAIL;
  if (thisLink->prev == USHRT_MAX) 
    FAIL;
  return Pl_Un_Atom(arcs[thisLink->prev].id_atom, prev);
}
/*
FORPROL find_arc_to(char* dest, char** arc) {
  id_list *end_pts;

  if (Get_Choice_Counter() == 0) {        // first invocation ?
    if (is_arc(dest))
      end_pts = arcs[get_arc_number(dest)]->arcs_to;
    else if (is_node(dest))
      end_pts = nodes[get_number(dest)]->arcs_to;
    else
      end_pts = NULL;

    if (!end_pts) {
      No_More_Choice();                      // remove choice-point
      FAIL;
    }
  } else
    end_pts = NULL;

  return run_through_list(end_pts, arc);
}
*/
FORPROL get_in_list_pointer(PlTerm dest, PlTerm inPtr) {
  char* destName;
  id_list* ptr;

  destName = Pl_Atom_Name(Pl_Rd_Atom(dest));
  if (is_arc(destName))
    ptr = arcs[get_arc_number(destName)].arcs_to;
  else if (is_node(destName))
    ptr = nodes[get_number(destName)].arcs_to;
  else
    ptr = NULL;
  return Pl_Un_Positive((uintptr_t)ptr, inPtr);
}
/*
FORPROL find_arc_from(char* source, char** arc) {
  id_list *end_pts;

  if (Get_Choice_Counter() == 0) {        // first invocation ?
    if (is_arc(source))
      end_pts = arcs[get_arc_number(source)]->arcs_from;
    else if (is_node(source))
      end_pts = nodes[get_number(source)]->arcs_from;
    else
      end_pts = NULL;

    if (!end_pts) {
      No_More_Choice();                      // remove choice-point
      FAIL;
    }
  } else
    end_pts = NULL;

  return run_through_list(end_pts, arc);
}
*/
FORPROL get_out_list_pointer(PlTerm src, PlTerm inPtr) {
  char* srcName;
  id_list* ptr;

  srcName = Pl_Atom_Name(Pl_Rd_Atom(src));
  if (is_arc(srcName))
    ptr = arcs[get_arc_number(srcName)].arcs_from;
  else if (is_node(srcName))
    ptr = nodes[get_number(srcName)].arcs_from;
  else
    ptr = NULL;
  return Pl_Un_Positive((uintptr_t)ptr, inPtr);
}

FORPROL get_next_list_pointer(PlTerm link, PlTerm nxtPtr) {
  arc* thisLink;
  char* linkName;
  id_list* ptr;

  ptr = NULL;
  linkName = Pl_Atom_Name(Pl_Rd_Atom(link));
  if (is_arc(linkName)) {
    thisLink = &(arcs[get_arc_number(linkName)]);
    if (arc_exists(thisLink))
      ptr = thisLink->subs;
  }
  return Pl_Un_Positive((uintptr_t)ptr, nxtPtr);
}

FORPROL get_class(PlTerm cNode, PlTerm cClass) {
  node* thisNode;
  char* cNodeName;
  /* OK, Sicstus external rules always succeed -- how do I tell Prolog there
     was no class? Another output? Can return val be other than FORPROL for GNU?
  */
  cNodeName = Pl_Atom_Name(Pl_Rd_Atom(cNode));
  if (!is_node(cNodeName))
    FAIL;
  thisNode = &(nodes[get_number(cNodeName)]);
  if (!node_exists(thisNode)) 
    FAIL;
  if (!thisNode->nclass)
    FAIL;
  return Pl_Un_Atom(thisNode->nclass, cClass);
}

FORPROL get_type(PlTerm cArc, PlTerm cClass) {
  arc* thisArc;
  char* cArcName;

  cArcName = Pl_Atom_Name(Pl_Rd_Atom(cArc));
  if (!is_arc(cArcName))
    FAIL;
  thisArc = &(arcs[get_arc_number(cArcName)]);
  if (!arc_exists(thisArc))
    FAIL;
  if (!thisArc->aclass)
    FAIL;
  return Pl_Un_Atom(thisArc->aclass, cClass);
}
