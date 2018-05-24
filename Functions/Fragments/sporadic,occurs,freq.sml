source(program='AME',version= 10.9,edition=evaluation,date='Thu May 24 14:58:56 GMT 2018').

roots([node00004,node00014,node00202,node00203,node00204,node00205,node00206]).

properties([complete-true,external_code-[procedure=none,include=none,libraries=[]],fill_colour-white,image_posn-none,multiplication_spec-[count=[]],name-'Desktop1']).

node(node00004,function,[],[complete=true,min_val=0,name=fn2,param_type=file,spec=latency,units=boolean,value=latency],[]).
node(node00014,cloud,[],[complete=true,name=cd5],[centre=[535,272]]).
node(node00202,event,[],[complete=true,name=occurs],[caption_offset=[0,0],centre=[374,141]]).
node(node00203,variable,[],[complete=true,max_val= 50.0,min_val=0,name=freq,units=1],[caption_offset=[0,0],centre=[610,68]]).
node(node00204,compartment,[],[complete=true,name=latency],[caption_offset=[0,0],centre=[373,272]]).
node(node00205,function,[],[complete=true,name=fn5,spec='exprnd(1)',units=1,value=exprnd(1)],[]).
node(node00206,cloud,[],[complete=true,name=cd4],[centre=[229,268]]).
node(node00013,function,[],[complete=true,name=fn6,spec='max(exprnd(1),1e-9-latency)',units=1/1,value=max(exprnd(1), 1.0e-009-latency)],[along=390]).
node(node00015,function,[],[complete=true,name=fn7,spec=freq,units=1/day,value=freq],[along=550]).

arc(arc00201,node00204,node00004,influence,[attached=[],complete=true,name=i4,role=[use(none,in_hierarchy,latency,1)]],[curve=[-18,-4]]).
arc(arc00007,node00204,node00014,flow,[attached=[node00015],complete=true,name=approach],[caption_offset=[0,1],curve=[550,1000]]).
arc(arc00002,node00004,node00202,influence,[attached=[],name=i2],[]).
arc(arc00202,node00205,node00204,influence,[attached=[],name=i3],[]).
arc(arc00203,node00206,node00204,squirt,[attached=[node00013],comment='Comp may be -ve if last event delayed so make sure it goes back above 0',complete=true,name=set],[caption_offset=[0,0],curve=[550,1000]]).
arc(arc00009,node00202,node00013,influence,[attached=[],complete=true,name=i5],[curve=[21,8]]).
arc(arc00204,node00204,node00013,influence,[attached=[],complete=true,name=i1,role=[use(none,in_hierarchy,latency,1)]],[curve=[-4,9]]).
arc(arc00010,node00203,node00015,influence,[attached=[],complete=true,name=i6,role=[use(none,in_hierarchy,freq,1)]],[curve=[33,21]]).
