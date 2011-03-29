% ######################## START OF SYMMETRICAL MAPPING SECTION ##########################

% Note that there is quite a lot of scope for reducing the number of map/3 clauses, since quite
% a few simply map an atom in Prolog to an atom in the XML.   We could therefore have a single
% rule which applies to all mode/element name combinations in a list.  I have not done that since
% it is easier to read through a set of rules, and since in future I might tightnen up on checks 
% (e.g. boolean/alphanumeric/numeric).

% ------------------------ TOP

map(top,
  source(program=P,version=Vn,edition=E,date=D),
  element(source,[],
    [element(program,[],[P]),
     element(version,[],[Va]),
     element(edition,[],[E]),
     element(date,[],
       [element(day,[],[Day]),
        element(month,[],[Month]),
        element(day_number,[],[Day_number]),
        element(hour,[],[Hour]),
        element(minute,[],[Minute]),
        element(second,[],[Second]),
        element(time_zone,[],[Time_zone]),
        element(year,[],[Year])])])):-
   atom_number(Va,Vn),
   extract_date(D,[Day,Month,Day_number,Hour,Minute,Second,Time_zone,Year]).

map(top,
  roots(RootListProlog),
  element(roots,[],RootListXML)):-
        map_list(subnode,RootListProlog,RootListXML).

map(top,
  properties(PropertiesListProlog),
  element(properties,[],PropertiesListXML)):-
        map_list(property, PropertiesListProlog, PropertiesListXML).

map(top,
  links(Submodel,LinksListProlog),
  element(links,[submodel=Submodel],LinksListXML)):-
        map_list(link, LinksListProlog, LinksListXML).

map(top,
  references(Submodel,RefsListProlog),
  element(references,[submodel=Submodel],RefsListXML)):-
        map_list(reference,RefsListProlog,RefsListXML).


%This clause is for the special (aberrant?) case of no specs.
map(top,
  node(ID,Type,[],[],[]),
  element(node,[id=ID,type=Type],[])).

map(top,
  node(ID,Type,[],SpecsProlog,[]),
  element(node,[id=ID,type=Type],
    [element(nodespecs,[],SpecsXML)])):-
         map_list(node_arc,SpecsProlog,SpecsXML).

map(top,
  node(ID,Type,[],SpecsProlog,GraphicsProlog),
  element(node,[id=ID,type=Type],[element(nodespecs,[],SpecsXML),element(nodegraphics,[],GraphicsXML)])):-
     map_list(node_arc,SpecsProlog,SpecsXML),
     map_list(node_arc,GraphicsProlog,GraphicsXML).

map(top,
  node(ID,Type,SublistProlog,SpecsProlog,GraphicsProlog),
  element(node,[id=ID,type=Type],
    [element(subnodes,[],SublistXML),
     element(nodespecs,[],SpecsXML),
     element(nodegraphics,[],GraphicsXML)])):-
         %mapsublist(SublistProlog,SublistXML),
         map_list(subnode,SublistProlog,SublistXML),
         map_list(node_arc,SpecsProlog,SpecsXML),
         map_list(node_arc,GraphicsProlog,GraphicsXML).

map(top,
  arc(ID,From,To,Type,SpecsProlog,[]),
  element(arc,[id=ID,from=From,to=To,type=Type],
    [element(arcspecs,[],SpecsXML)])):-
         map_list(node_arc,SpecsProlog,SpecsXML).

map(top,
  arc(ID,From,To,Type,SpecsProlog,GraphicsProlog),
  element(arc,[id=ID,from=From,to=To,type=Type],
    [element(arcspecs,[],SpecsXML),
     element(arcgraphics,[],GraphicsXML)])):-
         map_list(node_arc,SpecsProlog,SpecsXML),
         map_list(node_arc,GraphicsProlog,GraphicsXML).


map(top,end_of_file,'').



% ------------------------------------- SUBNODE

map(subnode, 
   A, 
   element(subnode,[],[A])):-
      atom(A).



% ------------------------------------- LINK

map(link, 
   Arc1-Arc2, 
   element(link,[arc1=Arc1,arc2=Arc2],[])):-
      atom(Arc1),
      atom(Arc2).



% ------------------------------------- REFERENCE

map(reference,
  local(Arc),
  element(local,[],[Arc])).

map(reference,
  ancestor(I),
  element(ancestor,[],[A])):-
      atom_number(A,I).

map(reference,
  obsolete,
  element(obsolete,[],[])).


% ------------------------------------- REF_ATTRIBUTE

map(ref_attribute,
   A,
   element(ref,[],[A])).



% ------------------------------------- NODE_ARC and PROPERTY
% Node, arc and property specification and graphical attributes

% First, a cool trick.    All node and arc attributes have the form A=V, wile all property
% attributes have the form A-V.   Rather than duplicate the rules for the (fairly large) subset
% subset of node attributes which are also property attributes, I use the following couple of
% rules to handle them appropriately, by using the Mode argument for map/3.    The actual
% mapping rules are expressed using map/2, with the A=V syntax.    (I could have used map/3, and
% put in a Mode such as node_arc_property, but there was no actual need to do this, so I didn't.)

% Note that there is thus no distinction between property attributes, node spec or graphical 
% attributes, and arc spec or graphical attributes.  They've been lumped together because
% there is quite a lot of overlap (i.e. the same one is used in more than one context). This is 
% not a problem, since the job of the bi-directional mapper is not to check a model, but simply 
% to convert a model.  It is % therefore legitimate to assume that the model itself (whether in 
% Prolog or XML form) is valid.

map(node_arc,A=V,XML):-
   map(av,A=V,XML).

map(property,A-V,XML):-
   map(av,A=V,XML).

   

% ------------------------------------- AV (attribute-value, for properties, nodes and arcs)
map(av,
  bounding_box=[X1n,Y1n,X2n,Y2n],
  element(bounding_box,[],
    [element(coords,[x=X1a,y=Y1a],[]),
     element(coords,[x=X2a,y=Y2a],[])])):-
      atom_number(X1a,X1n),
      atom_number(Y1a,Y1n),
      atom_number(X2a,X2n),
      atom_number(Y2a,Y2n).

map(av,
  bowtie=[X1n,Y1n,X2n,Y2n],
  element(bowtie,[],
    [element(coords,[x=X1a,y=Y1a],[]),
     element(coords,[x=X2a,y=Y2a],[])])):-
      atom_number(X1a,X1n),
      atom_number(Y1a,Y1n),
      atom_number(X2a,X2n),
      atom_number(Y2a,Y2n).

map(av,
  can_lookup=N,
  element(can_lookup,[],[A])):-
      atom_number(A,N).

map(av,
  caption_offset=[Xn,Yn],
  element(caption_offset,[],
    [element(coords,[x=Xa,y=Ya],[])])):-
      atom_number(Xa,Xn),
      atom_number(Ya,Yn).

% Not in XSugar - legacy?
map(av,
  caption_offset=[Xn,Yn,P],
  element(caption_offset,[],
    [element(coords,[x=Xa,y=Ya],[]),
     element(position,[],[P])])):-
      atom_number(Xa,Xn),
      atom_number(Ya,Yn).

map(av,
  centre=[Xn,Yn],
  element(centre,[],
    [element(coords,[x=Xa,y=Ya],[])])):-
      atom_number(Xa,Xn),
      atom_number(Ya,Yn).

map(av,
  comment='',
  element(comment,[],[])).

map(av,
  comment=C,
  element(comment,[],[C])).

map(av,
  complete=C,
  element(complete,[],[C])).

map(av,
  course='',
  element(course,[],[])).

map(av,
  course=[[X1n,Y1n],[X2n,Y2n]],
  element(course,[],
    [element(coords,[x=X1a,y=Y1a],[]),
     element(coords,[x=X2a,y=Y2a],[])])):-
      atom_number(X1a,X1n),
      atom_number(Y1a,Y1n),
      atom_number(X2a,X2n),
      atom_number(Y2a,Y2n).

map(av,
  course=[[X1n,Y1n],[X2n,Y2n],[X3n,Y3n]],
  element(course,[],
    [element(coords,[x=X1a,y=Y1a],[]),
     element(coords,[x=X2a,y=Y2a],[]),
     element(coords,[x=X3a,y=Y3a],[])])):-
      atom_number(X1a,X1n),
      atom_number(Y1a,Y1n),
      atom_number(X2a,X2n),
      atom_number(Y2a,Y2n),
      atom_number(X3a,X3n),
      atom_number(Y3a,Y3n).

% Legacy? - not in XSugar.
map(av,
  course=[[X1n,Y1n],[X2n,Y2n],[X3n,Y3n],[X4n,Y4n]],
  element(course,[],
    [element(coords,[x=X1a,y=Y1a],[]),
     element(coords,[x=X2a,y=Y2a],[]),
     element(coords,[x=X3a,y=Y3a],[]),
     element(coords,[x=X4a,y=Y4a],[])])):-
      atom_number(X1a,X1n),
      atom_number(Y1a,Y1n),
      atom_number(X2a,X2n),
      atom_number(Y2a,Y2n),
      atom_number(X3a,X3n),
      atom_number(Y3a,Y3n),
      atom_number(X4a,X4n),
      atom_number(Y4a,Y4n).

map(av,
  curve=[Xn,Yn],
  element(curve,[],
    [element(coords,[x=Xa,y=Ya],[])])):-
      atom_number(Xa,Xn),
      atom_number(Ya,Yn).

map(av,
  description='',
  element(description,[],[])).

map(av,
  description=D,
  element(description,[],[D])).

map(av,
  desc='',
  element(description,[],[])).

map(av,
  desc=D,
  element(description,[],[D])).

map(av,
  enum_types=ETProlog,
  element(enum_types,[],ETXML)):-
      map_list(enum_type,ETProlog,ETXML).

map(av,
  exclusive=N,
  element(exclusive,[],[A])):-
      atom_number(A,N).

map(av,
  external_code=ECprolog,
  element(external_code,[],ECxml)):-
      map_list(ECprolog,ECxml).

map(av,
  file_name=F,
  element(file_name,[],[F])).

map(av,
  fill_colour=C,
  element(fill_colour,[],[C])).

map(av,
  fill_image=I,
  element(fill_image,[],[I])).

map(av,
  fix_math_args=F,
  element(fix_math_args,[],[F])).

map(av,
  hide_contents=H,
  element(hide_contents,[],[H])).

map(av,
  ident=I,
  element(ident,[],[I])).

map(av,
  image_posn=P,
  element(image_posn,[],[P])).

map(av,
  include=P,
  element(include,[],[P])).

map(av,
  internal_extent=[X1n,Y1n,X2n,Y2n],
  element(internal_extent,[],
    [element(coords,[x=X1a,y=Y1a],[]),
     element(coords,[x=X2a,y=Y2a],[])])):-
      atom_number(X1a,X1n),
      atom_number(Y1a,Y1n),
      atom_number(X2a,X2n),
      atom_number(Y2a,Y2n).

map(av,
  last_membership=LM,
  element(last_membership,[],[LM])).

map(av,
  libraries=LibsProlog,
  element(libraries,[],LibsXML)):-
    map_list(LibsProlog,LibsXML).

map(av,
  caption_offset=[Xn,Yn,P],
  element(caption_offset,[],
    [element(coords,[x=Xa,y=Ya],[]),
     element(position,[],[P])])):-
      atom_number(Xa,Xn),
      atom_number(Ya,Yn).

map(av,
  max_val=Number,
  element(max_val,[],[Atom])):-
      atom_number(Atom,Number).

map(av,
  metadata=MetadataProlog,
  element(metadata,[],MetadataXML)):-
      map_list(metadata,MetadataProlog,MetadataXML).

map(av,
  min_val=Number,
  element(min_val,[],[Atom])):-
      atom_number(Atom,Number).

map(av,
  multiplication_spec=MSProlog,
  element(multiplication_spec,[],MSXML)):-
      map_list(multiplication_spec,MSProlog,MSXML).

map(av,
  name=N,
  element(name,[],[N])).

map(av,
  param_type=P,
  element(param_type,[],[P])).

map(av,
  procedure=P,
  element(procedure,[],[P])).

map(av,
  references=RefsProlog,
  element(references,[],RefsXML)):-
      map_list(ref_attribute, RefsProlog, RefsXML).

map(av,
  role=Rprolog,
  element(role,[],Rxml)):-
      map_list(use,Rprolog,Rxml).

map(av,
  separate=Sn,
  element(separate,[],[Sa])):-
      atom_number(Sa,Sn).

% The list that's being checked for here is the list of characters in a 
% Prolog string.
map(av,
  spec=S,
  element(spec,[],[S2])):-
      is_list(S),!,
      name(S1,S),
      convert_number_to_atom(S1,S2).

map(av,
  spec=S,
  element(spec,[],[S])).

map(av,
  step=S,
  element(step,[],[S])).

/*
% ALERT!!!   This is a temporary fix to get things working.            ALERT!!!
%            the table_data attribute actually takes a list of 
%            attribute=value pairs, for some of which 'value' is 
%            itself a list.
map(av,
  table_data=TD,
  element(table_data,[],[TD])).
*/

/*
map(av,
  table_data=TDProlog,
  element(table_data,[],[TDXML])):-
      term_to_atom(TDProlog,TDXML).
*/


map(av,
  table_data=TDProlog,
  element(table_data,[],TDXML)):-
      map_list(table_data,TDProlog,TDXML).


map(av,
  units=U,
  element(units,[],[element('m:math',[],[Umath])])):-
      map(math,U,Umath).

map(av,
  use_sofar=N,
  element(use_sofar,[],[A])):-
   convert_number_to_atom(N,A).

map(av,
  value=V,
  element(value,[],[element('m:math',[],[Vmath])])):-
      map(math,V,Vmath).


% ------------------------------------- METADATA

map(metadata,
   submissionDate=date(Day,Month,Year),
   element(submissionDate,[],
     [element(day,[],[Day]),
      element(month,[],[Month]),
      element(year,[],[Year])])).

map(metadata,
   modelName=Name,
   element(modelName,[],[Name])).

map(metadata,
   modelPurpose=Purpose,
   element(modelPurpose,[],[Purpose])).

map(metadata,
   modeldescription=Description,
   element(modelDescription,[],[Description])).

map(metadata,
   originalModelDescription=Description,
   element(originalModelDescription,[],[Description])).

map(metadata,
   publications=PublistProlog,
   element(publications,[],PublistXML)):-
      map_list(publication,PublistProlog,PublistXML).

map(metadata,
   creators=CreatorlistProlog,
   element(creators,[],CreatorlistXML)):-
      map_list(person,CreatorlistProlog,CreatorlistXML).

map(metadata,
   submitter=Name,
   element(submitter,[],[Name])).



% ------------------------------------- PUBLICATION

map(publication,
   publication(ID,IDtype,Primary,Journal,Title,AuthorlistProlog,Abstract),
   element(publication,[id=ID,idType=IDtype,primary=Primary],[
      element(journal,[],[Journal]),
      element(title,[],[Title]),
      element(authors,[],AuthorlistXML),
      element(abstract,[],[Abstract])])):-
         map_list(person,AuthorlistProlog,AuthorlistXML).



% ------------------------------------- PERSON
map(person,
   person(FamilyName,GivenName,Em,Org),
   element(person,[],[
      element(family,[],[FamilyName]),
      element(given,[],[GivenName]),
      element(email,[],[Em]),
      element(org,[],[Org])])).



% ------------------------------------- MULTIPLICATION_SPEC

% This needs to be generalised.  Formally, it is defined as follows:
% A list of terms T, where each T is either 'count=Cs' or 'type=T'.
% Cs is a list of terms C, where C is an integer constant, an enumerated
% type constant, or an expression of the form 'size(S)', where S is 
% the name of a submodel. The number of Ns indicates the number of 
% dimensions. T is either 'records' or 'population'.

map(multiplication_spec,
  count=Cs,
  element(count,[],Ds)):-
      map_list(count_item,Cs,Ds).

map(multiplication_spec,
  type=records,
  element(type,[],[records])).    % Is this obsolete?

map(multiplication_spec,
  type=population,
  element(type,[],[population])).



% ------------------------------------- COUNT_ITEM
map(count_item,
   size(S),
   element(size,[],[S])).
map(count_item,
   An,
   element(dimension,[],[Aa])):-
      integer(An),
      atom_number(Aa,An),!.
map(count_item,
   A,
   element(enumerated_type,[],[A])).
% Note: value for 'constant' is given as content rather than as an attribute because
% it can be double-quoted.




% ------------------------------------- ENUM_TYPE

% Allows for (one-off?) example in drainage1.pl in Model Catalogue.
map(enum_type,
   ''-[],
   element(enum_type,[],[])).

map(enum_type,
   ETname-ETvalsProlog,
   element(enum_type,[name=ETname],ETvalsXML)):-
      map_list(enum_type_value,ETvalsProlog,ETvalsXML).



% ------------------------------------- ENUM_TYPE_VALUE

map(enum_type_value,
   ETvalue,
   element(enum_value,[],[ETvalue])).



% ------------------------------------- USE

% Role spec terms - see Twiki/Simile/SMLSyntaxAndSemantics for explanation.
% As A is local name of a quantity, and B is units for this quantity, both
% should be further elaborated to reveal their substructure.

map(use,
   use(Rprolog,W,Vprolog,Uprolog),
   element(use,[],
     [element(role,[],[Rxml]),
      element(way,[],[W]),
      element(local_name,[],[Vxml]),
      element(units,[],[element('m:math',[],[Umath])])])):-
         number_atom(Rprolog,Rxml),
         map(useV,Vprolog,Vxml),
         map(math,Uprolog,Umath).


map(useV,
   usr(V),
   element(usr,[],[V])):-!.
map(useV,
   Vterm,
   Vatom):-
      term_to_atom(Vterm,Vatom).

   



% ------------------------------------- TABLE_DATA

map(table_data,
   file=F,
   element(file,[],[F])).

map(table_data,
   data=Datum,
   element(data_single,[],[Datum])):-
      atom(Datum).

map(table_data,
   data=DataProlog,
   element(data_list,[],DataXML)):-
      map_list(atom,DataProlog,DataXML). 

map(table_data,
   indices=IndicesProlog,
   element(indices,[],IndicesXML)):-
      map_list(atom,IndicesProlog,IndicesXML). 

map(table_data,
   current=CurrentProlog,
   element(current,[],CurrentXML)):-
      map_list(number,CurrentProlog,CurrentXML). 

map(table_data,
   units=UProlog,
   element(units,[],[element('m:math',[],[Umath])])):-
      map(math,UProlog,Umath).

/*map(table_data,
   bounds=Bds,
   element(bounds,[],[Bds])):-
      atom(Bds).

map(table_data,
   bounds=BdsProlog,
   element(bounds,[],[BdsXML])):-
      atom_number(BdsXML,BdsProlog).

map(table_data,
   bounds=BdsProlog,
   element(array_bounds,[],[BdsXML])):-
      atom_number(BdsXML,BdsProlog).
*/

map(table_data,
   bounds=BdsProlog,
   element(bounds,[],[BdsXML])):-
      term_to_atom(BdsProlog,BdsXML).

/*
map(table_data,
   dims=Ds,
   element(dims,[],[Ds])).
*/
map(table_data,
   dims=DsProlog,
   element(dims,[],[DsXML])):-
      term_to_atom(DsProlog,DsXML).



map(atom,
   A,
   element(data,[],[A])).

map(number,
   N,
   element(data,[],[A])):-
      atom_number(A,N).



% ------------------------------------- MATH

map(math,V,element('m:ci',[],[V])):-
   atom(V).


map(math,V,element('m:cn',[],[Vatom])):-
   atom(Vatom),
   atom_number(Vatom,V).

map(math,V,element('m:cn',[],[Vatom])):-
   number(V),
   atom_number(Vatom,V).


% ------------------------------ if ... then ... elseif ... else
map(math,
   if A then B else C,
   element('m:piecewise',[],[element('m:piece',[],[Bmath,Amath]),element('m:otherwise',[],[Cmath])])):-
      map(math,A,Amath),
      map(math,B,Bmath),
      map(math,C,Cmath).


map(math,
   if A then B elseif E else C,
   element('m:piecewise',[],[element('m:piece',[],[Bmath,Amath])|Rest])):-
      map(math,A,Amath),
      map(math,B,Bmath),
      elseif_rule(E,Cmath,Rest),
      map(math,C,Cmath).


map(math,
   +A,
   element('m:apply',[],[element('m:plus',[],[]),Amath])):-
      map(math,A,Amath).

map(math,
   -A,
   element('m:apply',[],[element('m:minus',[],[]),Amath])):-
      map(math,A,Amath).


% "In MathML" means that the operator is defined in the MathML spec.
% "Not in MathML" means that it isn't - i.e. it is specific to Simile.

% I seem to need a pair of rules, in order to handle each direction separately (see ordering of subgoals).
% Would be better not to have to do this, but can't see how, without creating a problem with 
% insufficient instantiation.

% ------------------------------ Functions in MathML
% Zero-arity operator

% --- SimileProlog to SimileXMLv3
map(math,
   Expr,
   element(Opmath,[],[])):-
      var(Opmath),
      Expr =.. [Opsim,''],
      op(mathml,_,0,Opmath,Opsim).

% --- SimileXMLv3 to SimileProlog
map(math,
   Expr,
   element(Opmath,[],[])):-
      var(Expr),
      op(mathml,_,0,Opmath,Opsim),
      Expr =.. [Opsim,''].

% --- Unary operator
% --- SimileProlog to SimileXMLv3
map(math,
   Expr,
   element('m:apply',[],[element(Opmath,[],[]),Amath])):-
      var(Opmath),
      Expr =.. [Opsim,A],
      op(mathml,_,1,Opmath,Opsim),
      map(math,A,Amath).

% --- SimileXMLv3 to SimileProlog
map(math,
   Expr,
   element('m:apply',[],[element(Opmath,[],[]),Amath])):-
      var(Expr),
      op(mathml,_,1,Opmath,Opsim),
      map(math,A,Amath),
      Expr =.. [Opsim,A].

% --- Binary operator
% --- SimileProlog to SimileXMLv3
map(math,
   Expr,
   element('m:apply',[],[element(Opmath,[],[]),Amath,Bmath])):-
      var(Opmath),
      Expr =.. [Opsim,A,B],
      op(mathml,infix,2,Opmath,Opsim),
      map(math,A,Amath),
      map(math,B,Bmath).

% --- SimileXMLv3 to SimileProlog
map(math,
   Expr,
   element('m:apply',[],[element(Opmath,[],[]),Amath,Bmath])):-
      var(Expr),
      op(mathml,_,2,Opmath,Opsim),
      map(math,A,Amath),
      map(math,B,Bmath),
      Expr =.. [Opsim,A,B].


% --------------------------------- Functions not in MathML

% Any non-MathML functions.
% This includes BOTH non-MathML standrad-Simile functions AND any user-defined functions -
% no distinction is made between these two categoroes.
% This means that anything which looks like a function name is handled without raising
% an error, even if it's actually a mistake.   But of course mistakes should not happen,
% since models will generally be valid Simile models...

map(math,
   Expr,
   element('m:csymbol',[encoding=text,definitionURL=DefURL],[Opsim])):-
      var(Expr),
      make_def_url(Opsim,DefURL),
      Expr =.. [Opsim,''],!.

map(math,
   Expr,
   element('m:csymbol',[encoding=text,definitionURL=DefURL],[Opsim])):-
      var(Opsim),
      Expr =.. [Opsim,''],
      make_def_url(Opsim,DefURL),!.

map(math,
   Expr,
   element('m:apply',[],[element('m:csymbol',[encoding=text,definitionURL=DefURL],[Opsim])|ArgsXML])):-
      var(Expr),
      map_list(math,ArgsSim,ArgsXML),
      make_def_url(Opsim,DefURL),
      Expr =.. [Opsim|ArgsSim],!.

map(math,
   Expr,
   element('m:apply',[],[element('m:csymbol',[encoding=text,definitionURL=DefURL],[Opsim])|ArgsXML])):-
      var(Opsim),
      Expr =.. [Opsim|ArgsSim],
      map_list(math,ArgsSim,ArgsXML),
      make_def_url(Opsim,DefURL),!.


% ------------------------ Arrays, array variables and list variables

map(math,
   [A1,A2|As],
   element('m:vector',[class=array],[Amath1,Amath2|Amaths])):-
      map(math,A1,Amath1),
      map(math,A2,Amath2),
      map_list(math,As,Amaths),!.

map(math,
   [A],
   element('m:vector',[class=array],[Amath])):-
      map(math,A,Amath),!.

/*
map(math,
   As,
   Amaths):-
      map_list(math,As,Amaths),!.
*/

map(math,
   {A},
   element('m:vector',[class=list],[Amath])):-
      map(math,A,Amath),!.


% The bracketed, comma-separated term is an expression with assignments.
% The comma is left-associative, so all the assignments are picked up together.
% We then need to use a special predicate (like map_list) to handle them.
map(math,
   (A=B,Arest),
   element('m:where',[],[element('m:apply',[],[element('m:eq',[],[]),Amath,Bmath])|Arestmath])):-
      map(math,A,Amath),
      map(math,B,Bmath),
      map_assignments(Arest,Arestmath).



% END OF MATHS
% -----------------------------------------------------------------------------


%map(Mode,A,A):-
%   write('       *** ERROR *** Mode = '), write(Mode), write('Term = '),write(A),nl.


% END OF MAP
% ######################################################################################



% ------------------------------ MAP_LIST ----------------------------------

map_list(_,[],[]).

map_list(Mode,[A|As],[B|Bs]):-
  map(Mode,A,B),
  map_list(Mode,As,Bs).

map_list(Mode,[A|B],C):- write('ERROR from map_list/3: '),write(Mode),write(' '),write([A,' ::: ',B,' ... ',C]),nl,nl.



% -------------------------------- ELSEIF_RULE ---------------------------------------

elseif_rule(
   E1 then E2 elseif Erest,
   Cmath,
   [element('m:piece',[],[E2math,E1math])|Rest]):-
      map(math,E1,E1math),
      map(math,E2,E2math),
      elseif_rule(Erest,Cmath,Rest).
elseif_rule(
   E1 then E2,
   Cmath,
   [element('m:piece',[],[E2math,E1math]),element('m:otherwise',[],[Cmath])]):-
      map(math,E1,E1math),
      map(math,E2,E2math).



% ------------------------------- MAP_ASSIGNMENTS --------------------------------------

map_assignments(
   (A=B,Arest),
   [element('m:apply',[],[element('m:eq',[],[]),Amath,Bmath])|Arestmath]):-
      map(math,A,Amath),
      map(math,B,Bmath),
      map_assignments(Arest,Arestmath).
map_assignments((A),[Amath]):-
   map(math,A,Amath).


% ########################### END OF BI-DIRECTIONAL MAPPING SECTION #######################



lookup('*','m:xtimes').
lookup('/','m:xdivide').
lookup('+','m:xplus').
lookup('-','m:xminus').
lookup('^','m:xpower').

op(mathml, infix, 2, 'm:times', '*').   % Need to change it to arity n.
op(mathml, infix, 2, 'm:plus', '+').    % Need to change it to arity n.
op(mathml, infix, 2, 'm:divide', '/').
op(mathml, infix, 2, 'm:minus', '-').
op(mathml, infix, 2, 'm:power', '^').
op(mathml, infix, 2, 'm:eq', '==').
op(mathml, infix, 2, 'm:neq', '\\=').
op(mathml, infix, 2, 'm:gt', '>').
op(mathml, infix, 2, 'm:lt', '<').
op(mathml, infix, 2, 'm:geq', '>=').
op(mathml, infix, 2, 'm:leq', '<=').
op(mathml, infix, 2, 'm:and', and).
op(mathml, infix, 2, 'm:or', or).
op(mathml, infix, 2, 'm:xor', xor).
op(mathml, prefix, 1, 'm:abs', abs).
op(mathml, prefix, 1, 'm:arccos', acos).
op(mathml, prefix, 1, 'm:arccosh', acosh).
op(mathml, prefix, 1, 'm:arccoth', acoth).
op(mathml, prefix, 1, 'm:arccot', acot).
op(mathml, prefix, 1, 'm:arcsec', function_not_supported).
op(mathml, prefix, 1, 'm:arcsech', function_not_supported).
op(mathml, prefix, 1, 'm:arcsin', asin).
op(mathml, prefix, 1, 'm:arcsinh', asinh).
op(mathml, prefix, 1, 'm:arctan', atan).
op(mathml, prefix, 1, 'm:arctanh', function_not_supported).
op(mathml, prefix, 1, 'm:ceiling', ceil).
op(mathml, prefix, 1, 'm:cos', cos).
op(mathml, prefix, 1, 'm:cosh', cosh).
op(mathml, prefix, 1, 'm:cot', cot).
op(mathml, prefix, 1, 'm:coth', coth).
op(mathml, prefix, 1, 'm:csc', function_not_supported).
op(mathml, prefix, 1, 'm:exp', exp).
op(mathml, prefix, 1, 'm:factorial', factorial).
op(mathml, prefix, 1, 'm:floor', floor).
op(mathml, prefix, 1, 'm:ln', log).
op(mathml, prefix, 1, 'm:log', log10).
op(mathml, prefix, 1, 'm:power', pow).
op(mathml, prefix, 1, 'm:root', sqrt).
op(mathml, prefix, 1, 'm:sech', function_not_supported).
op(mathml, prefix, 1, 'm:sin', sin).
op(mathml, prefix, 1, 'm:sinh', sinh).
op(mathml, prefix, 1, 'm:tan', tan).
op(mathml, prefix, 1, 'm:tanh', tanh).
op(mathml, constant, 0, 'm:exponentiale', e).
op(mathml, constant, 0, 'm:pi', pi).

op(simile, prefix, 1, not_in_mathml, all).
op(simile, prefix, 1, not_in_mathml, any).
op(simile, prefix, 1, not_in_mathml, at_init).
op(simile, prefix, 2, not_in_mathml, binome).
op(simile, prefix, 1, not_in_mathml, channel_is).
op(simile, prefix, 1, not_in_mathml, colin).
op(simile, prefix, 1, not_in_mathml, count).
op(simile, prefix, 1, not_in_mathml, dt).
op(simile, prefix, 2, not_in_mathml, element).
op(simile, prefix, 1, not_in_mathml, first).
op(simile, prefix, 1, not_in_mathml, firsttrue).
op(simile, prefix, 1, not_in_mathml, fmod).
op(simile, prefix, 1, not_in_mathml, following).
op(simile, prefix, 2, not_in_mathml, gaussian_var).
op(simile, prefix, 1, not_in_mathml, greatest).
op(simile, prefix, 1, not_in_mathml, howmanytrue).
op(simile, prefix, 2, not_in_mathml, hypergeom).
op(simile, prefix, 2, not_in_mathml, hypot).
op(simile, prefix, 1, not_in_mathml, index).
op(simile, prefix, 1, not_in_mathml, init_time).
op(simile, prefix, 1, not_in_mathml, int).
op(simile, prefix, 1, not_in_mathml, last).
op(simile, prefix, 1, not_in_mathml, least).
op(simile, prefix, 1, not_in_mathml, log).
op(simile, prefix, 2, not_in_mathml, makearray).
op(simile, prefix, 2, not_in_mathml, max).
op(simile, prefix, 2, not_in_mathml, min).
op(simile, prefix, 1, not_in_mathml, parent).
op(simile, prefix, 1, not_in_mathml, place_in).
op(simile, prefix, 1, not_in_mathml, poidev).
op(simile, prefix, 1, not_in_mathml, posgreatest).
op(simile, prefix, 1, not_in_mathml, posleast).
op(simile, prefix, 1, not_in_mathml, preceding).
op(simile, prefix, 1, not_in_mathml, prev).
op(simile, prefix, 1, not_in_mathml, product).
op(simile, prefix, 2, not_in_mathml, rand_const).
op(simile, prefix, 2, not_in_mathml, rand_var).
op(simile, prefix, 1, not_in_mathml, rankings).
op(simile, prefix, 1, not_in_mathml, round).
op(simile, prefix, 1, not_in_mathml, sgn).
op(simile, prefix, 1, not_in_mathml, size).
op(simile, prefix, 2, not_in_mathml, size).
op(simile, prefix, 1, not_in_mathml, stop).
op(simile, prefix, 1, not_in_mathml, subtotals).
op(simile, prefix, 1, not_in_mathml, sum).
op(simile, prefix, 1, not_in_mathml, time).
op(simile, prefix, 2, not_in_mathml, with_colin).
op(simile, prefix, 2, not_in_mathml, with_greatest).
op(simile, prefix, 2, not_in_mathml, with_least).


% #################################### UTILITIES ################################

write_list([]).
write_list([H|T]):-writeq(H),write('.'),nl,write_list(T).

mysetof(A,B,C):-
  setof(A,B,C),!.
mysetof(_,_,[]).

mybagof(A,B,C):-
   bagof(A,B,C),!.
mybagof(_,_,[]).


my_tab(_).
my_nl.

/*
my_tab(N):-
   tab(N).
my_nl:-
   nl.
*/


% This is the definitive version of the mapping between atoms and numbers.
% This should replace all uses of (the built-in predicate) atom/number/2 and 
% convert_number_to_atom/2 (below).
% The name is chosen deliberately to have the same ordering (Prolog,XML) as 
% the map/3 predicate, and to emphasise the bi-directional aspect.

% This is needed because xml_write/3 fails when it tries to generate the XML for 
% a Prolog number.
/*
number_atom(N,A):-
   number(N),
   atom_number(A,N),!.
number_atom(A,A).
*/

% Go through and remove all instances, replacing with number_atom/2.
convert_number_to_atom(S1,S2):-
   number(S1),
   atom_number(S2,S1).
convert_number_to_atom(S2,S2).


% 'Fri Mar 05 18:16:09 GMT 2010'
extract_date(Date,[Day,Month,Day_number,Hour,Minute,Second,Time_zone,Year]):-
   atom(Date),!,
   sub_atom(Date,0,3,_,Day),
   sub_atom(Date,4,3,_,Month),
   sub_atom(Date,8,2,_,Day_number),
   sub_atom(Date,11,2,_,Hour),
   sub_atom(Date,14,2,_,Minute),
   sub_atom(Date,17,2,_,Second),
   sub_atom(Date,20,3,_,Time_zone),
   sub_atom(Date,24,4,_,Year).
extract_date(Date,DateList):-
   pad_numbers(DateList,DateList1),
   concat_atom(DateList1,' ',Date).

pad_numbers([Day,Month,Day_number,Hour,Minute,Second,Time_zone,Year],[Day,Month,Day_number1,Hour1,Minute1,Second1,Time_zone,Year]):-
   pad_number(Day_number,Day_number1),
   pad_number(Hour,Hour1),
   pad_number(Minute,Minute1),
   pad_number(Second,Second1).

pad_number(A,A1):-
   atom_length(A,1),
   concat('0',A,A1).
pad_number(A,A).


make_def_url(Opsim,DefURL):-
   atom_concat('http://www.simulistics.com/help/equations/functions/',Opsim,Partial),
   atom_concat(Partial,'.htm',DefURL).
