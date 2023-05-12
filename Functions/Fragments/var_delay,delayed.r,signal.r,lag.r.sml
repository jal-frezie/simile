source(program='Simile v7.0',version= 11.0,edition=enterprise,date='Fri May 12 11:57:19 GMT 2023').

roots([node00336,node00337,node00338,node00339,node00340,node00341,node00342,node00343,node00344,node00345,node00346,node00347,node00348]).

properties([complete-true,file_name-'/win98/Program Files/Simile/Develop/Library/shade.sml',fill_colour-white,min_val-0,name-'Desktop1',separate-0,units-1,value- 0.5]).

node(node00336,variable,[],[complete=true,max_val=100,min_val= 0.0,name=lag,spec='0',units=1,value=0],[caption_offset=[0,0],centre=[-3247,-127]]).
node(node00337,variable,[],[complete=true,name=resetting],[caption_offset=[0,0],centre=[-3402,-84]]).
node(node00338,function,[],[complete=true,name=fn101,spec='time()==at_init(time())',units=boolean,value=(time('')==at_init(time('')))],[]).
node(node00339,variable,[],[complete=true,name=find],[caption_offset=[0,0],centre=[-3192,-42]]).
node(node00340,function,[],[complete=true,name=fn102,spec='time()-lag',units=1,value=time('')-lag],[]).
node(node00341,variable,[],[complete=true,name=vals],[caption_offset=[0,0],centre=[-3473,25]]).
node(node00342,function,[],[complete=true,name=fn104,spec='makearray(if place_in(1)==1024 then signal elseif resetting then default(signal) else element(prev(0),place_in(1)+1),1024)',units=array(1,1024),value=makearray(if place_in(1)==1024 then signal elseif resetting then default(signal) else element(prev(0),place_in(1)+1),1024)],[]).
node(node00343,variable,[],[complete=true,name=times],[caption_offset=[0,0],centre=[-3280,-12]]).
node(node00344,function,[],[complete=true,name=fn105,spec='makearray(if place_in(1)==1024 then time() elseif resetting then time()-1 else element(prev(0),place_in(1)+1),1024)',units=array(1,1024),value=makearray(if place_in(1)==1024 then time('') elseif resetting then time('')-1 else element(prev(0),place_in(1)+1),1024)],[]).
node(node00345,submodel,[node00349,node00350,node00351,node00352,node00353,node00354,node00355,node00356,node00357,node00358,node00359],[complete=true,enum_types=[],external_code=[procedure=none,include=none,libraries=[]],fill_colour=white,image_posn=none,multiplication_spec=[count=[10]],name=level],[bounding_box=[-3333,69,-3046,295],caption_offset=[0,0],internal_extent=[0,0,287,225]]).
links(node00345,[arc00421-arc00430,arc00422-arc00431,arc00435-arc00438]).
node(node00349,variable,[],[complete=true,name=idx],[caption_offset=[0,0],centre=[57,196]]).
node(node00350,function,[],[complete=true,name=fn107,spec='lowside-dir*step',units=1,value=lowside-dir*step],[]).
node(node00351,variable,[],[complete=true,name=dir],[caption_offset=[0,0],centre=[171,120]]).
node(node00352,function,[],[complete=true,name=fn109,spec='if find>element([times],lowside-step) then 0 else 1',units=int,value=(if find>element([times],lowside-step) then 0 else 1)],[]).
node(node00353,variable,[],[complete=true,name=step],[caption_offset=[0,0],centre=[203,182]]).
node(node00354,function,[],[complete=true,name=fn110,spec='pow(2,10-index(1))',units=1,value=pow(2,10-index(1))],[]).
node(node00355,variable,[],[complete=true,name=lowside],[caption_offset=[0,0],centre=[58,124]]).
node(node00356,function,[],[complete=true,name=fn111,spec='if index(1)==1 then 1024 else in_preceding(idx)',units=1,value=(if index(1)==1 then 1024 else in_preceding(idx))],[]).
node(node00357,border,[],[name=bdr1],[along=767]).
node(node00358,border,[],[name=bdr2],[along=692]).
node(node00359,border,[],[name=bdr3],[along=466]).
node(node00346,variable,[],[complete=true,name=delayed],[caption_offset=[0,0],centre=[-3407,146]]).
node(node00347,function,[],[complete=true,name=fn204,spec='element([vals],element([idx],10))',units=1,value=element([vals],element([idx],10))],[]).
node(node00348,variable,[],[complete=true,max_val=100,min_val=0,name=signal,units=int],[caption_offset=[0,0],centre=[-3568,137]]).

arc(arc00413,node00338,node00337,influence,[attached=[],name=i101],[]).
arc(arc00414,node00340,node00339,influence,[attached=[],name=i104],[]).
arc(arc00415,node00336,node00340,influence,[attached=[],complete=true,name=i105,role=[use(none,in_hierarchy,lag,1)]],[curve=[12,-8]]).
arc(arc00416,node00342,node00341,influence,[attached=[],name=i110],[]).
arc(arc00417,node00337,node00342,influence,[attached=[],complete=true,name=i102,role=[use(none,in_hierarchy,resetting,boolean)]],[curve=[16,10]]).
arc(arc00418,node00348,node00342,influence,[attached=[],complete=true,name=i209,role=[use(none,in_hierarchy,signal,int)]],[curve=[-17,-14]]).
arc(arc00419,node00344,node00343,influence,[attached=[],name=i111],[]).
arc(arc00420,node00337,node00344,influence,[attached=[],complete=true,name=i103,role=[use(none,in_hierarchy,resetting,boolean)]],[curve=[11,-18]]).
arc(arc00421,node00339,node00345,influence,[attached=[],complete=true,name=i5],[curve=[18,1]]).
arc(arc00422,node00343,node00345,influence,[attached=[],complete=true,name=i7],[curve=[14,-4]]).
arc(arc00423,node00350,node00349,influence,[attached=[],name=i114],[]).
arc(arc00424,node00351,node00350,influence,[attached=[],complete=true,name=i122,role=[use(none,in_hierarchy,dir,int)]],[curve=[11,17]]).
arc(arc00425,node00355,node00350,influence,[attached=[],complete=true,name=i130,role=[use(none,in_hierarchy,lowside,1)]],[curve=[10,0]]).
arc(arc00426,node00353,node00350,influence,[attached=[],complete=true,name=i131,role=[use(none,in_hierarchy,step,1)]],[curve=[2,22]]).
arc(arc00427,node00352,node00351,influence,[attached=[],name=i118],[]).
arc(arc00428,node00355,node00352,influence,[attached=[],complete=true,name=i128,role=[use(none,in_hierarchy,usr(lowside),1)]],[curve=[-1,-16]]).
arc(arc00429,node00353,node00352,influence,[attached=[],complete=true,name=i129,role=[use(none,in_hierarchy,usr(step),1)]],[curve=[-8,4]]).
arc(arc00430,node00357,node00352,influence,[attached=[],complete=true,name=i6,role=[use(none,in_hierarchy,find,1)]],[curve=[18,-6]]).
arc(arc00431,node00358,node00352,influence,[attached=[],complete=true,name=i8,role=[use(none,in_hierarchy,[times],array(1,1024))]],[curve=[17,-14]]).
arc(arc00432,node00354,node00353,influence,[attached=[],name=i124],[]).
arc(arc00433,node00356,node00355,influence,[attached=[],name=i125],[]).
arc(arc00434,node00349,node00356,influence,[attached=[],complete=true,name=i126,role=[use(none,in_hierarchy,idx,1)]],[curve=[-10,0]]).
arc(arc00435,node00349,node00359,influence,[attached=[],complete=true,name=i10],[curve=[-11,6]]).
arc(arc00436,node00347,node00346,influence,[attached=[],name=i207],[]).
arc(arc00437,node00341,node00347,influence,[attached=[],complete=true,name=i210,role=[use(none,in_hierarchy,[vals],array(1,1024))]],[curve=[18,-10]]).
arc(arc00438,node00345,node00347,influence,[attached=[],complete=true,name=i9,role=[use(none,in_hierarchy,[idx],array(1,10))]],[curve=[-8,14]]).
