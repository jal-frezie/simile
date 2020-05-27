source(program='AME',version= 10.9,edition=evaluation,date='Thu May 24 15:06:04 GMT 2018').

roots([node00052,node00053,node00054,node00055,node00156,node00157,node00158]).

properties([complete-true,fill_colour-white,name-'Desktop1']).

node(node00052,variable,[],[complete=true,name=output],[caption_offset=[0,0],centre=[474,294]]).
node(node00053,function,[],[complete=true,name=fn1,spec='sum(element({empty},n))',units=1,value=sum(element({empty},n))],[]).
node(node00054,submodel,[node00159,node00160,node00161,node00162,node00163,node00164,node00165,node00166,node00167,node00168,node00169],[complete=true,enum_types=[],external_code=[procedure=none,include=none,libraries=[]],fill_colour=white,image_posn=none,multiplication_spec=[type=population],name=element,separate=0],[bounding_box=[237,28,383,415],caption_offset=[0,0],internal_extent=[0,0,146,387]]).
links(node00054,[arc00158-arc00163,arc00158-arc00169,arc00158-arc00175,arc00159-arc00166,arc00160-arc00168,arc00160-arc00174,arc00161-arc00171,arc00173-arc00156]).
node(node00159,border,[],[name=bdr1],[along=126]).
node(node00160,border,[],[name=bdr1],[along=481]).
node(node00161,border,[],[name=bdr2],[along=628]).
node(node00162,border,[],[name=bdr3],[along=372]).
node(node00163,creation,[],[complete=true,name=cr1],[caption_offset=[0,0],centre=[115,65]]).
node(node00164,function,[],[complete=true,name=fn110,spec=n,units=1,value=n],[]).
node(node00165,border,[],[name=bdr4],[along=951]).
node(node00166,compartment,[],[name=comp1],[caption_offset=[0,0],centre=[76,191]]).
node(node00167,function,[],[name=fn4,spec='initial*delay/n',units=1,value=initial*delay/n],[]).
node(node00168,cloud,[],[complete=true,name=cd1],[centre=[72,27]]).
node(node00169,cloud,[],[complete=true,name=cd2],[centre=[73,332]]).
node(node00055,variable,[],[complete=true,max_val=100,min_val=0,name=n,units=int],[caption_offset=[0,0],centre=[464,93]]).
node(node00156,variable,[],[complete=true,max_val=100,min_val=0,name=input,units=int],[caption_offset=[0,0],centre=[167,148]]).
node(node00157,variable,[],[complete=true,max_val=100,min_val=0,name=delay,units=int],[caption_offset=[0,0],centre=[167,298]]).
node(node00158,variable,[],[complete=true,max_val=100,min_val=0,name=initial,units=int],[caption_offset=[0,0],centre=[166,241]]).
node(node00171,function,[],[name=fn6,spec='n*comp1/delay',units=1/day,value=n*comp1/delay],[along=550]).
node(node00170,function,[],[name=fn5,spec='if index(1)==1 then input else in_preceding(empty)',units=1/day,value=(if index(1)==1 then input else in_preceding(empty))],[along=550]).

arc(arc00155,node00053,node00052,influence,[attached=[],name=i1],[]).
arc(arc00156,node00054,node00053,influence,[attached=[],complete=true,name=i2,role=[use(none,in_hierarchy,{empty},list(1/day))]],[curve=[-4,-14]]).
arc(arc00157,node00055,node00053,influence,[attached=[],complete=true,name=i4,role=[use(none,in_hierarchy,n,int)]],[curve=[31,-2]]).
arc(arc00158,node00055,node00054,influence,[attached=[],complete=true,name=i112],[curve=[14,16]]).
arc(arc00159,node00158,node00054,influence,[attached=[],complete=true,name=i5,role=[use(none,in_hierarchy,initial,int)]],[curve=[2,-11]]).
arc(arc00160,node00157,node00054,influence,[attached=[],complete=true,name=i9,role=[use(none,in_hierarchy,delay,int)]],[curve=[4,-10]]).
arc(arc00161,node00156,node00054,influence,[attached=[],complete=true,name=i6,role=[use(none,in_hierarchy,input,int)]],[curve=[3,-11]]).
arc(arc00173,node00171,node00159,influence,[attached=[],complete=true,name=i3],[curve=[6,-11]]).
arc(arc00162,node00164,node00163,influence,[attached=[],name=i111],[]).
arc(arc00163,node00165,node00164,influence,[attached=[],complete=true,name=i113,role=[use(none,in_hierarchy,n,int)]],[curve=[-13,12]]).
arc(arc00164,node00167,node00166,influence,[attached=[],name=i4],[]).
arc(arc00165,node00168,node00166,flow,[attached=[node00170],name=fill],[caption_offset=[0,0],curve=[550,1000]]).
arc(arc00166,node00160,node00167,influence,[attached=[],complete=true,name=i5,role=[use(none,in_hierarchy,initial,int)]],[curve=[-11,-8]]).
arc(arc00174,node00162,node00167,influence,[attached=[],complete=true,name=i38,role=[use(none,in_hierarchy,delay,int)]],[curve=[-18,-3]]).
arc(arc00175,node00165,node00167,influence,[attached=[],complete=true,name=i39,role=[use(none,in_hierarchy,n,int)]],[curve=[12,5]]).
arc(arc00167,node00166,node00169,flow,[attached=[node00171],name=empty],[caption_offset=[0,0],curve=[550,1000]]).
arc(arc00168,node00162,node00171,influence,[attached=[],complete=true,name=i9,role=[use(none,in_hierarchy,delay,int)]],[curve=[-6,-10]]).
arc(arc00169,node00165,node00171,influence,[attached=[],complete=true,name=i114,role=[use(none,in_hierarchy,n,int)]],[curve=[18,9]]).
arc(arc00170,node00166,node00171,influence,[attached=[],name=i8,role=[use(none,in_hierarchy,comp1,1)]],[curve=[9,5]]).
arc(arc00171,node00161,node00170,influence,[attached=[],complete=true,name=i6,role=[use(none,in_hierarchy,input,int)]],[curve=[-7,-9]]).
arc(arc00172,node00171,node00170,influence,[attached=[],complete=true,name=i115,role=[use(none,in_hierarchy,empty,1/day)]],[curve=[-24,0]]).
