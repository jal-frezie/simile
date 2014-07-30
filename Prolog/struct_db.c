#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <limits.h>

#ifdef _GNU_PROLOG
//    #include <libxml/xmlreader.h>

    #include "gprolog.h"
    #define FORPROL Bool
    #define FAIL return(FALSE)
    #define SUCCEED return(TRUE)

    #define PlAtom int
    #define NEW_ATOM Pl_Create_Atom
    #define TERMIFY(CH) Pl_Mk_Atom(Pl_Create_Allocate_Atom(CH))
    #define PL_unify_pointer(t, p) Pl_Un_Positive((uintptr_t)(p), t)

char* term_to_chars(PlTerm in, PlAtom* out) {
  *out = Pl_Rd_Atom(in);
  return Pl_Atom_Name(*out);
}

void PL_get_integer(PlTerm t, int* i) {
  *i = (int)Pl_Rd_Integer(t);
}

void PL_get_pointer(PlTerm t, void** p) {
  *p = (void*)Pl_Rd_Positive(t);
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

#endif
#ifdef __SWI_PROLOG__
    #include <SWI-Prolog.h>
    #define FORPROL foreign_t
    #define FAIL PL_fail
    #define SUCCEED PL_succeed

    #define PlTerm term_t
    #define PlAtom atom_t
    #define NEW_ATOM PL_new_atom
    #define TERMIFY(CH) PL_new_atom(strdup(CH))

    #define Pl_Un_Integer(n, t) PL_unify_integer(t, n)
    #define Pl_Un_Atom(a, t) PL_unify_atom(t, a)

const char* term_to_chars(PlTerm in, PlAtom* out) {
  PL_get_atom(in, out);
  return PL_atom_chars(*out);
}

FORPROL list_box_ints(int l, int t, int r, int b, PlTerm tgt) {
  PlTerm box = PL_new_term_ref();
  PlTerm n = PL_new_term_ref();

  PL_put_nil(box);
  PL_put_integer(n, b); 
  PL_cons_list(box, n, box);
  PL_put_integer(n, r); 
  PL_cons_list(box, n, box);
  PL_put_integer(n, t); 
  PL_cons_list(box, n, box);
  PL_put_integer(n, l); 
  PL_cons_list(box, n, box);

  return PL_unify(tgt, box);
}

FORPROL list_vect_ints(int x, int y, PlTerm tgt) {
  PlTerm box = PL_new_term_ref();
  PlTerm n = PL_new_term_ref();

  PL_put_nil(box);
  PL_put_integer(n, y); 
  PL_cons_list(box, n, box);
  PL_put_integer(n, x); 
  PL_cons_list(box, n, box);

  return PL_unify(tgt, box);
}
#endif
#ifdef _SICSTUS_PROLOG
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
PlAtom rootAtom;
  
typedef struct node_t {
  PlAtom id_atom;
  PlAtom nclass;
  PlAtom parent;
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
  PlAtom id_atom;
  PlAtom aclass;
  id_list *children;
  unsigned short dest;
  unsigned short source;
  unsigned short prev;
  id_list *subs;
  //  id_list *arcs_to;
  //  id_list *arcs_from;
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
FORPROL empty_tree(PlTerm root, PlTerm ushrtmx) {
  int count;
  for (count=0; count<USHRT_MAX; ++count) {
    nodes[count].hide = 0;
    arcs[count].id_atom = 0;
  }
  for (count=0; count<4*USHRT_MAX; ++count) {
    id_lists[count].me = USHRT_MAX;
  }
  roots = NULL;
  term_to_chars(root, &rootAtom);
  return Pl_Un_Integer(sizeof(arc), ushrtmx);
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

unsigned short get_node_number(const char* nodeId) {
  return atoi(nodeId+4);
}

unsigned short get_arc_number(const char* nodeId) {
  return atoi(nodeId+3);
}

void add_to_list(id_list** tgt, short int newId) {
  id_list *newItem;

  newItem = alloc_id_list();
  newItem->me = newId;
  newItem->next = *tgt;
  *tgt = newItem;
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
    
int is_node(const char* node) {
  return !strncmp(node, "node", 4);
}

int is_arc(const char* node) {
  return !strncmp(node, "arc", 3);
}

void remove_node_from_list(id_list** tgt, const char* oldId) {
  remove_from_list(tgt, get_node_number(oldId));
}

void remove_arc_from_list(id_list** tgt, const char* oldId) {
  remove_from_list(tgt, get_arc_number(oldId));
}

FORPROL create_node(PlTerm newnode) {
  node *childNode;
  PlAtom childAtom;
  
  childNode = &(nodes[get_node_number(term_to_chars(newnode, &childAtom))]);
  childNode->id_atom = childAtom;
  childNode->nclass = 0;
  childNode->children = NULL;
  childNode->arcs_to = NULL;
  childNode->arcs_from = NULL;
  childNode->b = INT_MIN;
  childNode->ib = INT_MIN;
  childNode->hide = EXISTS;
  childNode->offy = INT_MIN;
  childNode->cx = INT_MIN;
  childNode->cy = INT_MIN;
  SUCCEED;
}
  
FORPROL add_to_tree(PlTerm parent, PlTerm child) {
  PlAtom spareAtom;
  unsigned short parentNum, childNum;
  node *childNode;
  id_list **childList;
  const char* parentStr;

  childNum = get_node_number(term_to_chars(child, &spareAtom));
  childNode = &(nodes[childNum]);
  parentStr = term_to_chars(parent, &(childNode->parent));

  if (childNode->parent == rootAtom) {
    add_to_list(&roots, childNum);
  } else {
    if (is_arc(parentStr)) {
      parentNum = get_arc_number(parentStr);
      childList = &((arcs+parentNum)->children);
    } else {
      parentNum = get_node_number(parentStr);
      childList = &((nodes+parentNum)->children);
    }
    add_to_list(childList, childNum);
  }
  SUCCEED;
}

// just to shorten the code...
node* node_from_term(PlTerm term) {
  PlAtom spareAtom;

  return  &(nodes[get_node_number(term_to_chars(term, &spareAtom))]);
}

FORPROL set_class(PlTerm cNode, PlTerm cClass) {
  //  printf("debug_c Set class of %s to %d\n", cNode, cClass);

  term_to_chars(cClass, &(node_from_term(cNode)->nclass));
  SUCCEED;
}

FORPROL add_bbox(PlTerm parent, PlTerm l, PlTerm t, PlTerm r, PlTerm b) {
  node *parentNode;

  parentNode = node_from_term(parent);
  PL_get_integer(l, &(parentNode->l));
  PL_get_integer(t, &(parentNode->t));
  PL_get_integer(r, &(parentNode->r));
  PL_get_integer(b, &(parentNode->b));
  SUCCEED;
}

FORPROL add_iext(PlTerm parent, PlTerm il, PlTerm it, PlTerm ir, PlTerm ib) {
  node *parentNode;

  parentNode = node_from_term(parent);
  PL_get_integer(il, &(parentNode->il));
  PL_get_integer(it, &(parentNode->it));
  PL_get_integer(ir, &(parentNode->ir));
  PL_get_integer(ib, &(parentNode->ib));
  SUCCEED;
}

FORPROL add_capt_off(PlTerm parent, PlTerm offx, PlTerm offy) {
  node *Node;
  arc *Arc;
  const char* atomStr;
  PlAtom spareAtom;
  
  if (is_arc(atomStr = term_to_chars(parent, &spareAtom))) {
    Arc = &(arcs[get_arc_number(atomStr)]);
    PL_get_integer(offx, &(Arc->offx));
    PL_get_integer(offy, &(Arc->offy));
  } else {
    Node =  &(nodes[get_node_number(atomStr)]);
    PL_get_integer(offx, &(Node->offx));
    PL_get_integer(offy, &(Node->offy));
  }
  SUCCEED;
}

FORPROL add_centre(PlTerm parent, PlTerm cx, PlTerm cy) {
  node *parentNode;

  parentNode = node_from_term(parent);
  PL_get_integer(cx, &(parentNode->cx));
  PL_get_integer(cy, &(parentNode->cy));
  SUCCEED;
}

FORPROL add_along(PlTerm parent, PlTerm along) {
  node *parentNode;

  parentNode = node_from_term(parent);
  PL_get_integer(along, &(parentNode->cx));
  parentNode->cy = INT_MIN;
  SUCCEED;
}

FORPROL set_hidden(PlTerm parent, PlTerm whether) {
  unsigned char* hid_reg;
  int whetherInt;

  hid_reg = &(node_from_term(parent)->hide);
  PL_get_integer(whether, &whetherInt);
  if (whetherInt)
    *hid_reg = *hid_reg | HIDDEN;
  else
    *hid_reg = *hid_reg & ~HIDDEN;
  SUCCEED;
}

FORPROL create_arc(PlTerm newlink) {
  arc *newArc;
  PlAtom childAtom;
  
  newArc = &(arcs[get_arc_number(term_to_chars(newlink, &childAtom))]);
  newArc->id_atom = childAtom;
  newArc->aclass = 0;
  newArc->prev = USHRT_MAX;
  newArc->subs = NULL;
  newArc->children = NULL;
  //  newArc->arcs_to = NULL;
  //  newArc->arcs_from = NULL;
  newArc->yb = INT_MIN;
  newArc->offy = INT_MIN;
  SUCCEED;
}

FORPROL add_link(PlTerm dest, PlTerm source, PlTerm link) {
  arc *newArc;
  id_list** end_pts;
  const char* endName;
  unsigned short linkNum;
  PlAtom spareAtom;

  linkNum = get_arc_number(term_to_chars(link, &spareAtom));
  newArc = &(arcs[linkNum]);

  newArc->dest = get_node_number(term_to_chars(dest, &spareAtom));
  end_pts = &(nodes[newArc->dest].arcs_to);
  add_to_list(end_pts, linkNum);

  newArc->source = get_node_number(term_to_chars(source, &spareAtom));
  end_pts = &(nodes[newArc->source].arcs_from);
  add_to_list(end_pts, linkNum);
  SUCCEED;
}

FORPROL add_continuation(PlTerm before, PlTerm after) {
  arc *Arc;
  unsigned short afterNum;
  PlAtom spareAtom;

  afterNum = get_arc_number(term_to_chars(after, &spareAtom));
  Arc = &(arcs[afterNum]);
  Arc->prev = get_arc_number(term_to_chars(before, &spareAtom));
  Arc = &(arcs[Arc->prev]);
  add_to_list(&(Arc->subs), afterNum);
  SUCCEED;
}

// just to shorten the code...
arc* arc_from_term(PlTerm term) {
  PlAtom spareAtom;

  return  &(arcs[get_arc_number(term_to_chars(term, &spareAtom))]);
}

FORPROL set_type(PlTerm cArc, PlTerm cType) {
  term_to_chars(cType, &(arc_from_term(cArc)->aclass));
  SUCCEED;
}

FORPROL add_curve(PlTerm parent, PlTerm xk, PlTerm yb) {
  arc *parentArc;

  parentArc = arc_from_term(parent);
  PL_get_integer(xk, &(parentArc->xk));
  PL_get_integer(yb, &(parentArc->yb));
  SUCCEED;
}


FORPROL delete_node(PlTerm oldcomp) {
  node_from_term(oldcomp)->hide = 0;
  SUCCEED;
}

FORPROL remove_from_tree(PlTerm parent, PlTerm child) {
  PlAtom parentAtom;
  unsigned short parentNum;
  id_list **childList;
  const char* parentStr;
  const char* childStr;

  // no need to clear parent field in child, it will get another soon
  childStr = term_to_chars(child, &parentAtom);
  parentStr = term_to_chars(parent, &parentAtom);

  if (parentAtom == rootAtom) {
    remove_node_from_list(&roots, childStr);
  } else {
    if (is_arc(parentStr)) {
      parentNum = get_arc_number(parentStr);
      childList = &((arcs+parentNum)->children);
    } else {
      parentNum = get_node_number(parentStr);
      childList = &((nodes+parentNum)->children);
    }
    remove_node_from_list(childList, childStr);
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
  node_from_term(parent)->cx = INT_MIN;
  node_from_term(parent)->cy = INT_MIN;
  SUCCEED;
}
  
FORPROL remove_along(PlTerm parent) {
  return remove_centre(parent);
}
  
FORPROL remove_capt_off(PlTerm parent) {
  const char* parentStr;
  PlAtom spareAtom;

  parentStr = term_to_chars(parent, &spareAtom);
  if (is_arc(parentStr))
    arcs[get_arc_number(parentStr)].offy = INT_MIN;
  else
    nodes[get_node_number(parentStr)].offy = INT_MIN;
  SUCCEED;
}

FORPROL delete_arc(PlTerm oldlink) {
  arc_from_term(oldlink)->id_atom = 0;
  SUCCEED;
}

FORPROL remove_link(PlTerm dest, PlTerm source, PlTerm link) {
  id_list** end_pts;
  const char* linkName;
  const char* endName;
  PlAtom spareAtom;

  linkName = term_to_chars(link, &spareAtom);
  endName = term_to_chars(dest, &spareAtom);
  //  if (is_arc(endName))
  //    end_pts = &(arcs[get_arc_number(endName)].arcs_to);
  //  else 
    end_pts = &(nodes[get_node_number(endName)].arcs_to);
  remove_arc_from_list(end_pts, linkName);

  endName = term_to_chars(source, &spareAtom);
  //  if (is_arc(endName))
  //    end_pts = &(arcs[get_arc_number(endName)].arcs_from);
  //  else 
    end_pts = &(nodes[get_node_number(endName)].arcs_from);
  remove_arc_from_list(end_pts, linkName);
  SUCCEED;
}

FORPROL unset_type(PlTerm oldlink) {
  arc_from_term(oldlink)->aclass = 0;
  SUCCEED;
}

FORPROL remove_continuation(PlTerm before, PlTerm after) {
  const char* afterStr;
  PlAtom spareAtom;

  afterStr = term_to_chars(after, &spareAtom);
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
  const char* childStr;
  PlAtom spareAtom;

  childStr = term_to_chars(child, &spareAtom);

  if (!is_node(childStr))
    FAIL;
  childNode = &(nodes[get_node_number(childStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  return Pl_Un_Atom(childNode->parent, parent);
}

FORPROL find_bbox(PlTerm child, PlTerm result) {
  node* childNode;
  const char* childStr;
  PlAtom spareAtom;

  childStr = term_to_chars(child, &spareAtom);
  if (!is_node(childStr))
    FAIL;
  childNode = &(nodes[get_node_number(childStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  if (childNode->b == INT_MIN)
    FAIL;
  return list_box_ints(childNode->l, childNode->t, childNode->r, childNode->b, 
		       result);
}

FORPROL find_iext(PlTerm child, PlTerm result) {
  node* childNode;
  const char* childStr;
  PlAtom spareAtom;

  childStr = term_to_chars(child, &spareAtom);
  if (!is_node(childStr))
    FAIL;
  childNode = &(nodes[get_node_number(childStr)]);
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
  const char* compStr;
  PlAtom spareAtom;
  
  compStr = term_to_chars(comp, &spareAtom);
  if (is_arc(compStr)) {
    Arc = &(arcs[get_arc_number(compStr)]);
    if (!arc_exists(Arc)) 
      FAIL;
    if (Arc->offy == INT_MIN)
      FAIL;
    return list_vect_ints(Arc->offx, Arc->offy, result);
  } else if (is_node(compStr)) {
    Node = &(nodes[get_node_number(compStr)]);
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
  const char* nodeStr;
  PlAtom spareAtom;

  nodeStr = term_to_chars(child, &spareAtom);
  if (!is_node(nodeStr))
    FAIL;
  childNode = &(nodes[get_node_number(nodeStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  if (childNode->cy == INT_MIN)
    FAIL;
  return list_vect_ints(childNode->cx, childNode->cy, result);
}

FORPROL find_along(PlTerm child, PlTerm result) {
  node* childNode;
  const char* nodeStr;
  PlAtom spareAtom;

  nodeStr = term_to_chars(child, &spareAtom);
  if (!is_node(nodeStr))
    FAIL;
  childNode = &(nodes[get_node_number(nodeStr)]);
  if (!node_exists(childNode)) 
    FAIL;
  if (childNode->cx == INT_MIN)
    FAIL;
  if (childNode->cy != INT_MIN)
    FAIL;
  return Pl_Un_Integer(childNode->cx, result);
}

FORPROL is_hidden(PlTerm parent) {
  node* parentNode;
  const char* parentStr;
  PlAtom spareAtom;

  parentStr = term_to_chars(parent, &spareAtom);
  if (!is_node(parentStr))
    FAIL;
  parentNode = &(nodes[get_node_number(parentStr)]);
  if (!node_exists(parentNode)) 
    FAIL;
  if (parentNode->hide & HIDDEN)
    SUCCEED;
  FAIL;
}

FORPROL find_curve(PlTerm link, PlTerm result) {
  arc* childArc;
  const char* arcStr;
  PlAtom spareAtom;

  arcStr = term_to_chars(link, &spareAtom);
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
FORPROL find_child(const char* parent, const char** child) {
  id_list *p;

  if (Get_Choice_Counter() == 0) {        // first invocation ?
    if (!strcmp(parent, "root"))
      p = roots;
    else if (!is_node(parent))
      p = NULL;
    else
      p = nodes[get_node_number(parent)]->children;
  
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
  PlAtom parentAtom;
  id_list* result;
  const char* parentStr;
    
  parentStr = term_to_chars(parent, &parentAtom);
  if (parentAtom == rootAtom)
    result = roots;
  else {
    if (is_node(parentStr))
      result = nodes[get_node_number(parentStr)].children;
    else if (is_arc(parentStr))
      result = arcs[get_arc_number(parentStr)].children;
    else
      result = NULL;
  }
  return PL_unify_pointer(ptr, result);
}
/*
This used the nondeterministic features of the interface, but too complicated
and not portable. Easier to let Prolog decide whether to retry...

FORPROL run_through_list(id_list* p, const char** result) {
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
  
  PL_get_pointer(oldptr, (void**)&realPtr);
  if (!realPtr)
    FAIL;
  PL_unify_pointer(newptr, realPtr->next); // always succeed
  return Pl_Un_Atom(nodes[realPtr->me].id_atom, result);
}

FORPROL get_arc_and_next_ptr(PlTerm oldptr, PlTerm result, PlTerm newptr) {
  id_list* realPtr;
  
  PL_get_pointer(oldptr, (void**)&realPtr);
  if (!realPtr)
    FAIL;
  PL_unify_pointer(newptr, realPtr->next); // always succeed
  return Pl_Un_Atom(arcs[realPtr->me].id_atom, result);
}

FORPROL find_ends(PlTerm link, PlTerm source, PlTerm dest) {
  arc* thisLink;
  const char* linkName;
  PlAtom spareAtom;

  linkName = term_to_chars(link, &spareAtom);
  if (!is_arc(linkName))
    FAIL;
  thisLink = &(arcs[get_arc_number(linkName)]);
  if (!arc_exists(thisLink)) 
    FAIL;
  if (!Pl_Un_Atom(nodes[thisLink->source].id_atom, source)) 
    FAIL;
  if (!Pl_Un_Atom(nodes[thisLink->dest].id_atom, dest)) 
    FAIL;
  SUCCEED;
}

FORPROL find_prev(PlTerm link, PlTerm prev) {
  arc* thisLink;
  const char* linkName;
  PlAtom spareAtom;

  linkName = term_to_chars(link, &spareAtom);
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
FORPROL find_arc_to(const char* dest, const char** arc) {
  id_list *end_pts;

  if (Get_Choice_Counter() == 0) {        // first invocation ?
    if (is_arc(dest))
      end_pts = arcs[get_arc_number(dest)]->arcs_to;
    else if (is_node(dest))
      end_pts = nodes[get_node_number(dest)]->arcs_to;
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
  const char* destName;
  id_list* ptr;
  PlAtom spareAtom;

  destName = term_to_chars(dest, &spareAtom);
    //if (is_arc(destName))
    //  ptr = arcs[get_arc_number(destName)].arcs_to;
    //else   
  if (is_node(destName))
    ptr = nodes[get_node_number(destName)].arcs_to;
  else
    ptr = NULL;
  return PL_unify_pointer(inPtr, ptr);
}
/*
FORPROL find_arc_from(const char* source, const char** arc) {
  id_list *end_pts;

  if (Get_Choice_Counter() == 0) {        // first invocation ?
    if (is_arc(source))
      end_pts = arcs[get_arc_number(source)]->arcs_from;
    else if (is_node(source))
      end_pts = nodes[get_node_number(source)]->arcs_from;
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
  const char* srcName;
  id_list* ptr;
  PlAtom spareAtom;

  srcName = term_to_chars(src, &spareAtom);
    //if (is_arc(srcName))
    //  ptr = arcs[get_arc_number(srcName)].arcs_from;
    //else 
  if (is_node(srcName))
    ptr = nodes[get_node_number(srcName)].arcs_from;
  else
    ptr = NULL;
  return PL_unify_pointer(inPtr, ptr);
}

FORPROL get_next_list_pointer(PlTerm link, PlTerm nxtPtr) {
  arc* thisLink;
  const char* linkName;
  id_list* ptr;
  PlAtom spareAtom;

  linkName = term_to_chars(link, &spareAtom);
  ptr = NULL;
  if (is_arc(linkName)) {
    thisLink = &(arcs[get_arc_number(linkName)]);
    if (arc_exists(thisLink))
      ptr = thisLink->subs;
  }
  return PL_unify_pointer(nxtPtr, ptr);
}

FORPROL get_class(PlTerm cNode, PlTerm cClass) {
  node* thisNode;
  const char* cNodeName;
  PlAtom spareAtom;
  /* OK, Sicstus external rules always succeed -- how do I tell Prolog there
     was no class? Another output? Can return val be other than FORPROL for GNU?
  */

  cNodeName = term_to_chars(cNode, &spareAtom);
  if (!is_node(cNodeName))
    FAIL;
  thisNode = &(nodes[get_node_number(cNodeName)]);
  if (!node_exists(thisNode)) 
    FAIL;
  if (!thisNode->nclass)
    FAIL;
  return Pl_Un_Atom(thisNode->nclass, cClass);
}

FORPROL get_type(PlTerm cArc, PlTerm cClass) {
  arc* thisArc;
  const char* cArcName;
  PlAtom spareAtom;

  cArcName = term_to_chars(cArc, &spareAtom);
  if (!is_arc(cArcName))
    FAIL;
  thisArc = &(arcs[get_arc_number(cArcName)]);
  if (!arc_exists(thisArc))
    FAIL;
  if (!thisArc->aclass)
    FAIL;
  return Pl_Un_Atom(thisArc->aclass, cClass);
}

/* Stuff for reading an xml file using libxml2 -- abandoned because it was too
tricky getting it to build against the libraries in Windows and they would have
bloated it anyway. Only works with GNU.

PlAtom elementAtom, piAtom;

PlTerm processNode(xmlTextReaderPtr reader) {
  int ret, attrNum;
  PlTerm level, eltArgs[3];
  char scratch[1024];

  ret = xmlTextReaderRead(reader);
  if (ret)
    ret = xmlTextReaderNodeType(reader);
  else
    ret = 15;

  switch (ret) {
  case 1: // an element; call again to get contents, 
    level = Pl_Mk_List(NULL);
    for (attrNum = xmlTextReaderAttributeCount(reader); attrNum>0; ) {
      xmlTextReaderMoveToAttributeNo(reader, --attrNum);
      eltArgs[0] =TERMIFY(xmlTextReaderConstName(reader));
      eltArgs[1] = 
	TERMIFY(xmlTextReaderConstValue(reader));

      eltArgs[0] = Pl_Mk_Compound(Pl_Atom_Char('='), 2, eltArgs);
      eltArgs[1] = level;

      level = Pl_Mk_List(eltArgs);
      xmlTextReaderMoveToElement(reader);
    }

    eltArgs[0] = 
     TERMIFY(xmlTextReaderConstName(reader));
    // attribute-value pairs
    eltArgs[1] = level;
    if (xmlTextReaderIsEmptyElement(reader))
      eltArgs[2] = Pl_Mk_List(NULL);
    else
      eltArgs[2] = processNode(reader);
    level = Pl_Mk_Compound(elementAtom, 3, eltArgs);

    // then again for rest of list
    break;
  case 3: // a value: call again for rest of list and return
    level =TERMIFY(xmlTextReaderConstValue(reader));
    break;
  case 7: // a meta-element
    strcpy(scratch, xmlTextReaderConstName(reader));
    strcat(scratch, " ");
    strcat(scratch, xmlTextReaderConstValue(reader));
    eltArgs[0] =TERMIFY(scratch);
    level = Pl_Mk_Compound(piAtom, 1, eltArgs);

    // then again for rest of list
    break;
  case 14: // was same as 3, try just ignoring it and getting next one
    return processNode(reader); // looks like this was whitespace
  case 15: // end: return empty list
    return Pl_Mk_List(NULL);
  }

  eltArgs[0] = level;
  eltArgs[1] = processNode(reader);
  return Pl_Mk_List(eltArgs);
}

FORPROL xml_file_to_term(PlTerm fileNameTerm, PlTerm arising) {
  PlAtom spareAtom;
  PlTerm generated;
  xmlTextReaderPtr reader;
  int ret;
  const char* filename;
  
  elementAtom = NEW_ATOM("element");
  piAtom = NEW_ATOM("pi");
  filename = term_to_chars(fileNameTerm, &spareAtom);
  reader = xmlReaderForFile(filename, NULL, 0);
  if (reader != NULL) {
    generated = processNode(reader);
    xmlFreeTextReader(reader);
  } else {
    fprintf(stderr, "Unable to open %s\n", filename);
    FAIL;
  }

  xmlCleanupParser();
  return Pl_Unif(arising, generated);
}
// End of libxml2 stuff
*/
#ifdef __SWI_PROLOG__
install_t install() { 
  PL_register_foreign("empty_tree", 2, empty_tree, 0);

  PL_register_foreign("create_node", 1, create_node, 0);
  PL_register_foreign("add_to_tree", 2, add_to_tree, 0);
  PL_register_foreign("set_class", 2, set_class, 0);
  PL_register_foreign("add_bbox", 5, add_bbox, 0);
  PL_register_foreign("add_iext", 5, add_iext, 0);
  PL_register_foreign("add_capt_off", 3, add_capt_off, 0);
  PL_register_foreign("add_centre", 3, add_centre, 0);
  PL_register_foreign("add_along", 2, add_along, 0);
  PL_register_foreign("set_hidden", 2, set_hidden, 0);
  PL_register_foreign("create_arc", 1, create_arc, 0);
  PL_register_foreign("add_link", 3, add_link, 0);
  PL_register_foreign("add_continuation", 2, add_continuation, 0);
  PL_register_foreign("set_type", 2, set_type, 0);
  PL_register_foreign("add_curve", 3, add_curve, 0);

  PL_register_foreign("delete_node", 1, delete_node, 0);
  PL_register_foreign("remove_from_tree", 2, remove_from_tree, 0);
  PL_register_foreign("unset_class", 1, unset_class, 0);
  PL_register_foreign("remove_bbox", 1, remove_bbox, 0);
  PL_register_foreign("remove_iext", 1, remove_iext, 0);
  PL_register_foreign("remove_centre", 1, remove_centre, 0);
  PL_register_foreign("remove_along", 1, remove_along, 0);
  PL_register_foreign("remove_capt_off", 1, remove_capt_off, 0);
  PL_register_foreign("delete_arc", 1, delete_arc, 0);
  PL_register_foreign("remove_link", 3, remove_link, 0);
  PL_register_foreign("unset_type", 1, unset_type, 0);
  PL_register_foreign("remove_continuation", 2, remove_continuation, 0);
  PL_register_foreign("remove_curve", 1, remove_curve, 0);

  PL_register_foreign("find_parent", 2, find_parent, 0);
  PL_register_foreign("get_child_list_pointer", 2, get_child_list_pointer, 0);
  PL_register_foreign("get_class", 2, get_class, 0);
  PL_register_foreign("find_ends", 3, find_ends, 0);
  PL_register_foreign("get_in_list_pointer", 2, get_in_list_pointer, 0);
  PL_register_foreign("get_out_list_pointer", 2, get_out_list_pointer, 0);
  PL_register_foreign("get_type", 2, get_type, 0);
  PL_register_foreign("find_prev", 2, find_prev, 0);
  PL_register_foreign("get_next_list_pointer", 2, get_next_list_pointer, 0);
  PL_register_foreign("find_curve", 2, find_curve, 0);
  PL_register_foreign("find_bbox", 2, find_bbox, 0);
  PL_register_foreign("find_iext", 2, find_iext, 0);
  PL_register_foreign("find_capt_off", 2, find_capt_off, 0);
  PL_register_foreign("find_centre", 2, find_centre, 0);
  PL_register_foreign("find_along", 2, find_along, 0);
  PL_register_foreign("is_hidden", 1, is_hidden, 0);
  PL_register_foreign("get_node_and_next_ptr", 3, get_node_and_next_ptr, 0);
  PL_register_foreign("get_arc_and_next_ptr", 3, get_arc_and_next_ptr, 0);
  //  Next only used in GNU to replicate SWI's SGML library
  //  PL_register_foreign("xml_file_to_term", 2, xml_file_to_term, 0);
}
#endif
