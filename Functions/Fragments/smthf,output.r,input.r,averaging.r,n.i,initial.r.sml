source(program='AME',version= 10.9,edition=evaluation,date='Thu May 24 15:06:35 GMT 2018').

roots([node00102,node00107,node00110,node00213,node00218,node00221,node00222]).

properties([complete-true,fill_colour-white,name-'Desktop1']).

node(node00102,submodel,[node00103,node00104,node00105,node00109,node00112,node00215,node00216,node00217,node00220,node00223],[complete=true,enum_types=[],external_code=[procedure=none,include=none,libraries=[]],fill_colour=white,image_posn=none,multiplication_spec=[type=population],name=submodel1,separate=0],[bounding_box=[156,57,577,270],caption_offset=[0,0],internal_extent=[0,0,421,213]]).
links(node00102,[arc00104-arc00105,arc00107-arc00108,arc00112-arc00113,arc00112-arc00117,arc00115-arc00116,arc00120-arc00119]).
node(node00103,compartment,[],[complete=true,name=comp],[caption_offset=[0,0],centre=[317,93]]).
node(node00104,function,[],[complete=true,name=fn1,spec=initial,units=1,value=initial],[]).
node(node00105,cloud,[],[complete=true,name=cd1],[centre=[93,93]]).
node(node00109,border,[],[name=bdr1],[along=666]).
node(node00112,border,[],[name=bdr2],[along=783]).
node(node00215,creation,[],[complete=true,name=cr1],[caption_offset=[0,0],centre=[69,165]]).
node(node00216,function,[],[complete=true,name=fn6,spec=n,units=1,value=n],[]).
node(node00217,border,[],[name=bdr3],[along=377]).
node(node00220,border,[],[name=bdr4],[along=97]).
node(node00223,border,[],[name=bdr5],[along=185]).
node(node00107,variable,[],[complete=true,max_val=100,min_val=0,name=input,units=int],[caption_offset=[0,0],centre=[277,15]]).
node(node00110,variable,[],[complete=true,max_val=100,min_val=0,name=averaging,units=int],[caption_offset=[0,0],centre=[398,16]]).
node(node00213,variable,[],[complete=true,max_val=100,min_val=0,name=n,units=int],[caption_offset=[0,0],centre=[219,310]]).
node(node00218,variable,[],[complete=true,max_val=100,min_val=0,name=initial,units=int],[caption_offset=[0,0],centre=[534,311]]).
node(node00221,variable,[],[complete=true,name=output],[caption_offset=[0,0],centre=[393,309]]).
node(node00222,function,[],[complete=true,name=fn8,spec='sum(element({comp},n))',units=1,value=sum(element({comp},n))],[]).
node(node00106,function,[],[complete=true,name=fn2,spec='((if index(1)==1 then input else in_preceding(comp))-comp)*n/averaging',units=1/day,value=((if index(1)==1 then input else in_preceding(comp))-comp)*n/averaging],[along=550]).

arc(arc00104,node00107,node00102,influence,[attached=[],complete=true,name=i3],[curve=[8,-1]]).
arc(arc00107,node00110,node00102,influence,[attached=[],complete=true,name=i6],[curve=[5,5]]).
arc(arc00112,node00213,node00102,influence,[attached=[],complete=true,name=i11],[curve=[-4,-8]]).
arc(arc00115,node00218,node00102,influence,[attached=[],complete=true,name=i14],[curve=[-7,-1]]).
arc(arc00101,node00104,node00103,influence,[attached=[],name=i1],[]).
arc(arc00102,node00105,node00103,flow,[attached=[node00106],complete=true,name=change],[caption_offset=[0,0],curve=[550,1000]]).
arc(arc00116,node00220,node00104,influence,[attached=[],complete=true,name=i15,role=[use(none,in_hierarchy,initial,int)]],[curve=[-15,14]]).
arc(arc00111,node00216,node00215,influence,[attached=[],name=i10],[]).
arc(arc00113,node00217,node00216,influence,[attached=[],complete=true,name=i12,role=[use(none,in_hierarchy,n,int)]],[curve=[0,11]]).
arc(arc00120,node00103,node00223,influence,[attached=[],complete=true,name=i19],[curve=[14,16]]).
arc(arc00118,node00222,node00221,influence,[attached=[],name=i17],[]).
arc(arc00119,node00102,node00222,influence,[attached=[],complete=true,name=i18,role=[use(none,in_hierarchy,{comp},list(1))]],[curve=[7,-1]]).
arc(arc00121,node00213,node00222,influence,[attached=[],complete=true,name=i20,role=[use(none,in_hierarchy,n,int)]],[curve=[0,-27]]).
arc(arc00105,node00109,node00106,influence,[attached=[],complete=true,name=i4,role=[use(none,in_hierarchy,input,int)]],[curve=[11,-14]]).
arc(arc00108,node00112,node00106,influence,[attached=[],complete=true,name=i7,role=[use(none,in_hierarchy,averaging,int)]],[curve=[15,-3]]).
arc(arc00109,node00103,node00106,influence,[attached=[],complete=true,name=i8,role=[use(none,in_hierarchy,comp,1)]],[curve=[-7,14]]).
arc(arc00117,node00217,node00106,influence,[attached=[],complete=true,name=i16,role=[use(none,in_hierarchy,n,int)]],[curve=[-22,-14]]).
