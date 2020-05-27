source(program='AME',version= 10.9,edition=evaluation,date='Thu May 24 15:07:25 GMT 2018').

roots([node00140,node00141,node00142,node00143,node00144,node00145,node00146,node00151]).

properties([complete-true,fill_colour-white,name-'Desktop1']).

node(node00140,compartment,[],[complete=true,name='Average input'],[caption_offset=[0,0],centre=[519,110]]).
node(node00141,function,[],[complete=true,name=fn1,spec='input-(averaging*initial)',units=1,value=input-averaging*initial],[]).
node(node00142,cloud,[],[complete=true,name=cd1],[centre=[261,110]]).
node(node00143,variable,[],[complete=true,max_val=100,min_val=0,name=averaging,units=int],[caption_offset=[0,0],centre=[452,194]]).
node(node00144,variable,[],[complete=true,name=trend],[caption_offset=[0,0],centre=[598,247]]).
node(node00145,function,[],[complete=true,name=fn4,spec='(input-Average_input)/(Average_input*averaging)',units=1,value=(input-'Average_input')/('Average_input'*averaging)],[]).
node(node00146,variable,[],[complete=true,max_val=100,min_val=0,name=input,units=int],[caption_offset=[0,0],centre=[265,257]]).
node(node00151,variable,[],[complete=true,max_val=100,min_val=0,name=initial,units=int],[caption_offset=[0,0],centre=[349,36]]).
node(node00150,function,[],[complete=true,name=fn2,spec='(input-Average_input)/averaging',units=1/day,value=(input-'Average_input')/averaging],[along=550]).

arc(arc00240,node00141,node00140,influence,[attached=[],name=i1],[]).
arc(arc00241,node00142,node00140,flow,[attached=[node00150],complete=true,name='change in average'],[caption_offset=[0,0],curve=[550,1000]]).
arc(arc00242,node00146,node00141,influence,[attached=[],complete=true,name=i106,role=[use(none,in_hierarchy,input,int)]],[curve=[-29,-34]]).
arc(arc00255,node00143,node00141,influence,[attached=[],complete=true,name=i114,role=[use(none,in_hierarchy,averaging,int)]],[curve=[-14,-4]]).
arc(arc00256,node00151,node00141,influence,[attached=[],complete=true,name=i115,role=[use(none,in_hierarchy,initial,int)]],[curve=[4,-27]]).
arc(arc00243,node00145,node00144,influence,[attached=[],name=i3],[]).
arc(arc00244,node00140,node00145,influence,[attached=[],complete=true,name=i9,role=[use(none,in_hierarchy,'Average_input',1)]],[curve=[22,-7]]).
arc(arc00245,node00143,node00145,influence,[attached=[],complete=true,name=i10,role=[use(none,in_hierarchy,averaging,int)]],[curve=[8,-22]]).
arc(arc00246,node00146,node00145,influence,[attached=[],complete=true,name=i11,role=[use(none,in_hierarchy,input,int)]],[curve=[-2,-53]]).
arc(arc00251,node00140,node00150,influence,[attached=[],complete=true,name=i7,role=[use(none,in_hierarchy,'Average_input',1)]],[curve=[-6,16]]).
arc(arc00252,node00143,node00150,influence,[attached=[],complete=true,name=i8,role=[use(none,in_hierarchy,averaging,int)]],[curve=[-10,9]]).
arc(arc00253,node00146,node00150,influence,[attached=[],complete=true,name=i17,role=[use(none,in_hierarchy,input,int)]],[curve=[-23,-20]]).
