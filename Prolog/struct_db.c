#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#ifdef _GNU_PROLOG
    #include "gprolog.h"
    #define FORPROL Bool
    #define FAIL return(FALSE)
    #define SUCCEED return(TRUE)
#else
    #include "../System/include/sicstus.h"
    #define FORPROL void
    #define FAIL {SP_fail();return;}
    #define SUCCEED return
#endif

typedef struct id_list_t {
  char me[10];
  struct id_list_t *next;
} id_list;
  
typedef struct node_t {
  char name[10];
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
  int aclass;
  char dest[10];
  char source[10];
  char prev[10];
  id_list *subs;
  id_list *arcs_to;
  id_list *arcs_from;
  int bl,bt,br,bb; // to go
  int offx, offy;
  int xk, yb;
} arc;
    
node* nodes[USHRT_MAX];
arc* arcs[USHRT_MAX];
id_list* roots = NULL;

long usedBits = 0;
void* safe_malloc(count) {
  long ptr;

  ptr = (long)malloc(count);
  if (ptr & ~usedBits) {
    usedBits = usedBits|ptr;
    printf("debug_c malloc uses new bits, mask now %lx\n", usedBits);
  }
  return (void*)ptr;
}

FORPROL empty_tree() {
  unsigned short count;
  for (count=0; count<USHRT_MAX; ++count) {
    nodes[count] = NULL;
    arcs[count] = NULL;
  }
  SUCCEED;
}

unsigned short get_number(char* nodeId) {
  return atoi(nodeId+4);
}

unsigned int get_arc_number(char* nodeId) {
  return atoi(nodeId+3);
}

void add_to_list(id_list** tgt, char* newId) {
  id_list *newItem;

  newItem = safe_malloc(sizeof(id_list));
  strcpy(newItem->me, newId);
  newItem->next = *tgt;
  *tgt = newItem;
}

void remove_from_list(id_list** tgt, char* oldId) {
  id_list *here;

  here = *tgt;
  if (here) {
    remove_from_list(&(here->next), oldId);
    
    if (!strcmp(oldId, here->me)) {
      *tgt = here->next;
      free(here); 
    }
  }
}
    
FORPROL create_node(char* newnode) {
  node *childNode;

  childNode = safe_malloc(sizeof(node));
  strcpy(childNode->name, newnode);
  nodes[get_number(newnode)] = childNode;
  childNode->nclass = 0;
  childNode->children = NULL;
  childNode->arcs_to = NULL;
  childNode->arcs_from = NULL;
  childNode->b = INT_MIN;
  childNode->ib = INT_MIN;
  childNode->hide = 0;
  childNode->offy = INT_MIN;
  childNode->cy = INT_MIN;
  SUCCEED;
}
  
FORPROL add_to_tree(char* parent, char* child) {
  unsigned short parentNum;
  node *childNode, *parentNode;

  childNode = nodes[get_number(child)];
  if (strcmp("root", parent)) {
    childNode->parent = get_number(parent);
    parentNode = nodes[childNode->parent];
    add_to_list(&(parentNode->children), child);
  } else {
    childNode->parent = USHRT_MAX;
    add_to_list(&roots, child);
  }
  SUCCEED;
}

FORPROL add_bbox(char* parent, long l, long t, long r, long b) {
  node *parentNode;

  parentNode =  nodes[get_number(parent)];
  parentNode->l = (int)l;
  parentNode->t = (int)t;
  parentNode->r = (int)r;
  parentNode->b = (int)b;
  SUCCEED;
}

FORPROL add_iext(char* parent, long il, long it, long ir, long ib) {
  node *parentNode;

  parentNode =  nodes[get_number(parent)];
  parentNode->il = (int)il;
  parentNode->it = (int)it;
  parentNode->ir = (int)ir;
  parentNode->ib = (int)ib;
  SUCCEED;
}

FORPROL add_capt_off(char* parent, long offx, long offy) {
  node *Node;
  arc *Arc;
  
  if (is_arc(parent)) {
    Arc = arcs[get_arc_number(parent)];
    Arc->offx = (int)offx;
    Arc->offy = (int)offy;
  } else {
    Node =  nodes[get_number(parent)];
    Node->offx = (int)offx;
    Node->offy = (int)offy;
  }
  SUCCEED;
}

FORPROL add_centre(char* parent, long cx, long cy) {
  node *parentNode;

  parentNode =  nodes[get_number(parent)];
  parentNode->cx = (int)cx;
  parentNode->cy = (int)cy;
  SUCCEED;
}

FORPROL set_hidden(char* parent, long whether) {
  nodes[get_number(parent)]->hide = (unsigned char)whether;
  SUCCEED;
}

FORPROL create_arc(char* newlink) {
  arc *newArc;

  newArc = safe_malloc(sizeof(arc));
  arcs[get_arc_number(newlink)] = newArc;
  newArc->aclass = 0;
  *newArc->prev = 0;
  newArc->subs = NULL;
  newArc->arcs_to = NULL;
  newArc->arcs_from = NULL;
  newArc->yb = INT_MIN;
  newArc->bb = INT_MIN;
  newArc->offy = INT_MIN;
  SUCCEED;
}

FORPROL add_link(char* dest, char* source, char* link) {
  arc *newArc;
  id_list** end_pts;

  newArc = arcs[get_arc_number(link)];
  strcpy(newArc->dest, dest);
  strcpy(newArc->source, source);
  if (is_arc(dest))
    end_pts = &(arcs[get_arc_number(dest)]->arcs_to);
  else 
    end_pts = &(nodes[get_number(dest)]->arcs_to);
  add_to_list(end_pts, link);
  if (is_arc(source))
    end_pts = &(arcs[get_arc_number(source)]->arcs_from);
  else 
    end_pts = &(nodes[get_number(source)]->arcs_from);
  add_to_list(end_pts, link);
  SUCCEED;
}

FORPROL add_continuation(char* before, char* after) {
  arc *Arc;

  Arc = arcs[get_arc_number(after)];
  strcpy(Arc->prev, before);
  Arc = arcs[get_arc_number(before)];
  add_to_list(&(Arc->subs), after);
  SUCCEED;
}

FORPROL add_curve(char* parent, long xk, long yb) {
  arc *parentArc;

  parentArc = arcs[get_arc_number(parent)];
  parentArc->xk = (int)xk;
  parentArc->yb = (int)yb;
  SUCCEED;
}

FORPROL delete_node(char* oldcomp) {
  node** oldNode;

  oldNode = &(nodes[get_number(oldcomp)]);
  free(*oldNode);
  *oldNode = NULL;
  SUCCEED;
}

FORPROL remove_from_tree(char* parent, char* child) {
  node* parentNode;

  if (strcmp(parent, "root")) {
    parentNode = nodes[get_number(parent)];
    remove_from_list(&(parentNode->children), child);
  } else {
    remove_from_list(&roots, child);
  }
  SUCCEED;
}

FORPROL remove_bbox(char* parent) {
  nodes[get_number(parent)]->b = INT_MIN;
  SUCCEED;
}
  
FORPROL remove_iext(char* parent) {
  nodes[get_number(parent)]->ib = INT_MIN;
  SUCCEED;
}
  
FORPROL remove_capt_off(char* parent) {
  if (is_arc(parent))
    arcs[get_arc_number(parent)]->offy = INT_MIN;
  else
    nodes[get_number(parent)]->offy = INT_MIN;
  SUCCEED;
}

FORPROL remove_centre(char* parent) {
  nodes[get_number(parent)]->cy = INT_MIN;
  SUCCEED;
}
  
FORPROL delete_arc(char* oldlink) {
  arc** oldArc;

  oldArc = &(arcs[get_arc_number(oldlink)]);
  free(*oldArc);
  *oldArc = NULL;
  SUCCEED;
}

FORPROL remove_link(char* dest, char* source, char* link) {
  id_list** end_pts;

  if (is_arc(dest))
    end_pts = &(arcs[get_arc_number(dest)]->arcs_to);
  else 
    end_pts = &(nodes[get_number(dest)]->arcs_to);
  remove_from_list(end_pts, link);
  if (is_arc(source))
    end_pts = &(arcs[get_arc_number(source)]->arcs_from);
  else 
    end_pts = &(nodes[get_number(source)]->arcs_from);
  remove_from_list(end_pts, link);
  SUCCEED;
}

FORPROL remove_continuation(char* before, char* after) {
  arc *Arc;

  Arc = arcs[get_arc_number(after)];
  if (!Arc) {
    printf("debug_c lost subs arc %s-%s\n", before, after);
    FAIL;
  }
  *Arc->prev = 0;
  Arc = arcs[get_arc_number(before)];
  if (!Arc) {
    printf("debug_c lost prev arc %s-%s\n", before, after);
    FAIL;
  }
  remove_from_list(&(Arc->subs), after);
  SUCCEED;
}

FORPROL remove_curve(char* parent) {
  arcs[get_arc_number(parent)]->yb = INT_MIN;
  SUCCEED;
}
  
int is_node(char* node) {
  return !strncmp(node, "node", 4);
}

int is_arc(char* node) {
  return !strncmp(node, "arc", 3);
}

FORPROL find_parent(char* child, char** parent) {
  node* childNode;

  if (!is_node(child))
    FAIL;
  childNode = nodes[get_number(child)];
  if (!childNode) 
    FAIL;
  if (childNode->parent == USHRT_MAX)
    *parent = "root";
  else
    *parent = nodes[childNode->parent]->name;
  SUCCEED;
}

FORPROL find_bbox(char* child, long* l, long* t, long* r, long* b) {
  node* childNode;

  if (!is_node(child))
    FAIL;
  childNode = nodes[get_number(child)];
  if (!childNode) 
    FAIL;
  if (childNode->b == INT_MIN)
    FAIL;
  *l = (long)childNode->l;
  *t = (long)childNode->t;
  *r = (long)childNode->r;
  *b = (long)childNode->b;
  SUCCEED;
}

FORPROL find_iext(char* child, long* il, long* it, long* ir, long* ib) {
  node* childNode;

  if (!is_node(child))
    FAIL;
  childNode = nodes[get_number(child)];
  if (!childNode) 
    FAIL;
  if (childNode->ib == INT_MIN)
    FAIL;
  *il = (long)childNode->il;
  *it = (long)childNode->it;
  *ir = (long)childNode->ir;
  *ib = (long)childNode->ib;
  SUCCEED;
}

FORPROL find_capt_off(char* parent, long* offx, long* offy) {
  node *Node;
  arc *Arc;
  
  if (is_arc(parent)) {
    Arc = arcs[get_arc_number(parent)];
    if (!Arc) 
      FAIL;
    if (Arc->offy == INT_MIN)
      FAIL;
    *offx = (long)Arc->offx;
    *offy = (long)Arc->offy;
    SUCCEED;
  } else if (is_node(parent)) {
    Node = nodes[get_number(parent)];
    if (!Node)
      FAIL;
    if (Node->offy == INT_MIN)
      FAIL;
    *offx = (long)Node->offx;
    *offy = (long)Node->offy;
    SUCCEED;
  } else
      FAIL;
}

FORPROL find_centre(char* child, long* cx, long* cy) {
  node* childNode;

  if (!is_node(child))
    FAIL;
  childNode = nodes[get_number(child)];
  if (!childNode) 
    FAIL;
  if (childNode->cy == INT_MIN)
    FAIL;
  *cx = (long)childNode->cx;
  *cy = (long)childNode->cy;
  SUCCEED;
}

FORPROL is_hidden(char* parent) {
  node* childNode;

  if (!is_node(parent))
    FAIL;
  childNode = nodes[get_number(parent)];
  if (!childNode) 
    FAIL;
  if (!childNode->hide)
    FAIL;
  SUCCEED;
}

FORPROL find_curve(char* child, long* xk, long* yb) {
  arc* childArc;

  if (!is_arc(child))
    FAIL;
  childArc = arcs[get_arc_number(child)];
  if (!childArc) 
    FAIL;
  if (childArc->yb == INT_MIN)
    FAIL;
  *xk = (long)childArc->xk;
  *yb = (long)childArc->yb;
  SUCCEED;
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
FORPROL get_child_list_pointer(char* parent, unsigned long* ptr) {
    if (!strcmp(parent, "root"))
      *ptr = (unsigned long)roots;
    else if (!is_node(parent))
      *ptr = (unsigned long)NULL;
    else
      *ptr = (unsigned long)nodes[get_number(parent)]->children;
    SUCCEED;
}
/*
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
FORPROL get_string_and_next_ptr(unsigned long oldptr, char** result, 
			     unsigned long *newptr) {
  *result = ((id_list*)oldptr)->me;
  *newptr = (unsigned long)((id_list*)oldptr)->next;
  SUCCEED;
}

FORPROL find_ends(char* link, char** source, char** dest) {
  arc* thisLink;

  if (!is_arc(link))
    FAIL;
  thisLink = arcs[get_arc_number(link)];
  if (!thisLink) 
    FAIL;
  *source = thisLink->source;
  *dest = thisLink->dest;
  SUCCEED;
}

FORPROL find_prev(char* link, char** prev) {
  arc* thisLink;

  if (!is_arc(link))
    FAIL;
  thisLink = arcs[get_arc_number(link)];
  if (!thisLink) 
    FAIL;
  if (!*thisLink->prev) 
    FAIL;
  *prev = thisLink->prev;
  SUCCEED;
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
FORPROL get_in_list_pointer(char* dest, unsigned long* ptr) {
  if (is_arc(dest))
    *ptr = (unsigned long)arcs[get_arc_number(dest)]->arcs_to;
  else if (is_node(dest))
    *ptr = (unsigned long)nodes[get_number(dest)]->arcs_to;
  else
    *ptr = (unsigned long)NULL;
  SUCCEED;
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
FORPROL get_out_list_pointer(char* dest, unsigned long* ptr) {
  if (is_arc(dest))
    *ptr = (unsigned long)arcs[get_arc_number(dest)]->arcs_from;
  else if (is_node(dest))
    *ptr = (unsigned long)nodes[get_number(dest)]->arcs_from;
  else
    *ptr = (unsigned long)NULL;
  SUCCEED;
}

FORPROL get_next_list_pointer(char* link, unsigned long* ptr) {
  arc* thisLink;

  *ptr = (unsigned long)NULL;
  if (is_arc(link)) {
    thisLink = arcs[get_arc_number(link)];
    if (thisLink) 
      *ptr = (unsigned long)thisLink->subs;
  }
  SUCCEED;
}

FORPROL set_class(char* cNode, int cClass) {
  //  printf("debug_c Set class of %s to %d\n", cNode, cClass);
  nodes[get_number(cNode)]->nclass = cClass;
  SUCCEED;
}

FORPROL set_type(char* cNode, int cClass) {
  arcs[get_arc_number(cNode)]->aclass = cClass;
  SUCCEED;
}

FORPROL unset_class(char* cNode, int cClass) {
  node* thisNode;

  thisNode = nodes[get_number(cNode)];
  thisNode->nclass = 0;
  SUCCEED;
}

FORPROL unset_type(char* cNode, int cClass) {
  arc* thisNode;

  thisNode = arcs[get_arc_number(cNode)];
  thisNode->aclass = 0;
  SUCCEED;
}

FORPROL get_class(char* cNode, int* cClass) {
  node* thisNode;
  /* OK, Sicstus external rules always succeed -- how do I tell Prolog there
     was no class? Another output? Can return val be other than FORPROL for GNU?
  */
  *cClass = 0;
  if (!is_node(cNode))
    FAIL;
  thisNode = nodes[get_number(cNode)];
  if (!thisNode)
    FAIL;
  if (!thisNode->nclass)
    FAIL;
  *cClass = thisNode->nclass;
  SUCCEED;
}

FORPROL get_type(char* cNode, int* cClass) {
  arc* thisNode;

  if (!is_arc(cNode))
    FAIL;
  thisNode = arcs[get_arc_number(cNode)];
  if (!thisNode)
    FAIL;
  if (!thisNode->aclass)
    FAIL;
  *cClass = thisNode->aclass;
  SUCCEED;
}
