source(program='Simile v7.1',version=11.1,edition=teaching,date='Wed Oct 18 08:52:46 GMT 2023').

roots([node00141,node00146,node00201,node00202,node00229]).

properties([complete-true,fill_colour-white,name-'Desktop1']).

node(node00141,submodel,[node00001,node00135,node00136,node00137,node00138,node00142,node00143,node00203,node00225],[complete=true,fill_colour=white,name='tri repetae'],[bounding_box=[107.0,-130.0,811.0,486.0],caption_offset=[0.0,0.0],internal_extent=[0.0,0.0,704.0,616.0]]).
links(node00141,[arc00304-arc00303,arc00332-arc00301,arc00332-arc00333]).
node(node00001,submodel,[node00011,node00101,node00112,node00113,node00114,node00115,node00116,node00117,node00118,node00119,node00120,node00121,node00122,node00123,node00124,node00129,node00130,node00139,node00140,node00145,node00215,node00216,node00226,node00303,node00304,node00305],[complete=true,enum_types=[],external_code=[procedure=none,include=none,libraries=[]],fill_colour=white,image_posn=none,multiplication_spec=[count=[size(start)]],name=merge,separate=0],[bounding_box=[86.0,139.0,590.0,492.0],caption_offset=[0.0,0.0],internal_extent=[0.0,0.0,504.0,353.0]]).
links(node00001,[arc00102-arc00304,arc00137-arc00318,arc00140-arc00141,arc00140-arc00324,arc00140-arc00330,arc00152-arc00153,arc00208-arc00207,arc00333-arc00206,arc00333-arc00334]).
node(node00011,variable,[],[complete=true,name=in],[caption_offset=[0.0,0.0],centre=[41.0,106.0]]).
node(node00101,border,[],[name=bdr1],[along=573]).
node(node00112,function,[],[complete=true,name=fn203,spec='if al2 then index(1) else out',units=int,value=(if al2 then index(1)else out)],[]).
node(node00113,variable,[],[complete=true,name=top],[caption_offset=[0.0,0.0],centre=[232.0,48.0]]).
node(node00114,function,[],[complete=true,name=fn204,spec='index(1)-bottoms_taken',units=int,value=index(1)-bottoms_taken],[]).
node(node00115,variable,[],[complete=true,name=bottom],[caption_offset=[0.0,0.0],centre=[239.0,235.0]]).
node(node00116,function,[],[complete=true,name=fn205,spec='start_bottom+bottoms_taken',units=int,value=start_bottom+bottoms_taken],[]).
node(node00117,variable,[],[complete=true,name='at top'],[caption_offset=[0.0,0.0],centre=[146.0,41.0]]).
node(node00118,function,[],[complete=true,name=fn206,spec='element([all_in],top)',units=int,value=element([all_in],top)],[]).
node(node00119,variable,[],[complete=true,name='at bottom'],[caption_offset=[0.0,0.0],centre=[111.0,199.0]]).
node(node00120,function,[],[complete=true,name=fn207,spec='element([all_in],bottom)',units=int,value=element([all_in],bottom)],[]).
node(node00121,variable,[],[complete=true,name='take top'],[caption_offset=[0.0,0.0],centre=[203.0,134.0]]).
node(node00122,function,[],[complete=true,name=fn208,spec='bottom>=min(start_bottom+sublist_in,count([start])+1) or top<start_bottom and element([start],at_top)<element([start],at_bottom)',units=boolean,value=(bottom>=min(start_bottom+sublist_in,count([start])+1)or top<start_bottom and element([start],at_top)<element([start],at_bottom))],[]).
node(node00123,variable,[],[complete=true,name=out],[caption_offset=[0.0,0.0],centre=[115.0,99.0]]).
node(node00124,function,[],[complete=true,name=fn209,spec='if take_top then at_top else at_bottom',units=int,value=(if take_top then at_top else at_bottom)],[]).
node(node00129,variable,[],[complete=true,name='start bottom'],[caption_offset=[0.0,0.0],centre=[365.0,210.0]]).
node(node00130,function,[],[complete=true,name=fn212,spec='(index(1)-1)//sublist_out*sublist_out+sublist_in+1',units=int,value=(index(1)-1)//sublist_out*sublist_out+sublist_in+1],[]).
node(node00139,border,[],[name=bdr1],[along=823]).
node(node00140,border,[],[name=bdr2],[along=755]).
node(node00145,border,[],[name=bdr4],[along=598]).
node(node00215,variable,[],[complete=true,name='bottoms taken'],[caption_offset=[0.0,0.0],centre=[287.0,72.0]]).
node(node00216,function,[],[complete=true,name=fn5,spec='if index(1)==start_bottom-sublist_in then 0 else in_preceding(prev(0)+(if take_top then 0 else 1))',units=int,value=(if index(1)==start_bottom-sublist_in then 0 else in_preceding(prev(0)+(if take_top then 0 else 1)))],[]).
node(node00226,border,[],[name=bdr6],[along=512]).
node(node00303,variable,[],[complete=true,name=right],[caption_offset=[0.0,0.0],centre=[98.46600000000001,18.155]]).
node(node00304,function,[],[complete=true,name=fn2,spec='index(1)==1 or element([start],out)>element([start],in_preceding(out))',units=boolean,value=(index(1)==1 or element([start],out)>element([start],in_preceding(out)))],[]).
node(node00305,border,[],[name=bdr1],[along=627]).
node(node00135,variable,[],[complete=true,name='sublist in'],[caption_offset=[0.0,0.0],centre=[275.0,55.0]]).
node(node00136,function,[],[complete=true,name=fn215,spec='if al2 then 1 else sublist_out',units=int,value=(if al2 then 1 else sublist_out)],[]).
node(node00137,variable,[],[complete=true,name='sublist out'],[caption_offset=[0.0,0.0],centre=[428.0,68.0]]).
node(node00138,function,[],[complete=true,name=fn216,spec='2*sublist_in',units=int,value=2*sublist_in],[]).
node(node00142,alarm,[],[complete=true,name=al2],[caption_offset=[0.0,0.0],centre=[78.0,56.0]]).
node(node00143,function,[],[complete=true,name=fn217,spec='sublist_out>=count([start]) or all([right])',units=boolean,value=(sublist_out>=count([start])or all([right]))],[]).
node(node00203,border,[],[name=bdr1],[along=564]).
node(node00225,border,[],[name=bdr5],[along=501]).
node(node00146,variable,[],[complete=true,max_val=100,min_val=0,name=start,spec='[4,2,5,3,1]',units=array(1,5),value=[4,2,5,3,1]],[caption_offset=[0.0,0.0],centre=[-37.0,140.0]]).
node(node00201,variable,[],[complete=true,name=order],[caption_offset=[0.0,0.0],centre=[1.0,-15.0]]).
node(node00202,function,[],[complete=true,name=fn1,spec='[out]',units=array(int,5),value=[out]],[]).
node(node00229,border,[],[name=bdr7],[along=917]).

arc(arc00332,node00146,node00141,influence,[attached=[],complete=true,name=i130],[curve=[5,-35]]).
arc(arc00137,node00137,node00001,influence,[attached=[],complete=true,name=i237],[curve=[10,4]]).
arc(arc00140,node00135,node00001,influence,[attached=[],complete=true,name=i240],[curve=[11,1]]).
arc(arc00152,node00142,node00001,influence,[attached=[],complete=true,name=i252],[curve=[15,4]]).
arc(arc00333,node00225,node00001,influence,[attached=[],complete=true,name=i131],[curve=[-2,-14]]).
arc(arc00103,node00112,node00011,influence,[attached=[],name=i203],[]).
arc(arc00102,node00123,node00101,influence,[attached=[],complete=true,name=i2],[curve=[-11,17]]).
arc(arc00001,node00123,node00112,influence,[attached=[],complete=true,name=i1,role=[use(none,in_hierarchy,out,int)],use_sofar=1],[curve=[1,10]]).
arc(arc00153,node00145,node00112,influence,[attached=[],complete=true,name=i253,role=[use(none,in_hierarchy,usr(al2),boolean)],use_sofar=1],[curve=[14,-7]]).
arc(arc00104,node00114,node00113,influence,[attached=[],name=i204],[]).
arc(arc00325,node00215,node00114,influence,[attached=[],complete=true,name=i125,role=[use(none,in_hierarchy,usr(bottoms_taken),int)]],[curve=[-7,6]]).
arc(arc00105,node00116,node00115,influence,[attached=[],name=i205],[]).
arc(arc00126,node00129,node00116,influence,[attached=[],complete=true,name=i226,role=[use(none,in_hierarchy,usr(start_bottom),int)]],[curve=[0,12]]).
arc(arc00326,node00215,node00116,influence,[attached=[],complete=true,name=i126,role=[use(none,in_hierarchy,usr(bottoms_taken),int)]],[curve=[20,5]]).
arc(arc00106,node00118,node00117,influence,[attached=[],name=i206],[]).
arc(arc00107,node00011,node00118,influence,[attached=[],complete=true,enabled_roles=[-1],name=i207,role=[use(-1,up_hierarchy,usr([all_in]),array(int,7654321))],suppressed_roles=[none],use_sofar=0],[curve=[-10,-15]]).
arc(arc00108,node00113,node00118,influence,[attached=[],complete=true,name=i208,role=[use(none,in_hierarchy,top,int)]],[curve=[-1,12]]).
arc(arc00110,node00120,node00119,influence,[attached=[],name=i210],[]).
arc(arc00111,node00011,node00120,influence,[attached=[],complete=true,enabled_roles=[-1],name=i211,role=[use(-1,up_hierarchy,usr([all_in]),array(int,7654321))],suppressed_roles=[none],use_sofar=0],[curve=[14,-10]]).
arc(arc00112,node00115,node00120,influence,[attached=[],complete=true,name=i212,role=[use(none,in_hierarchy,bottom,int)]],[curve=[-5,19]]).
arc(arc00113,node00122,node00121,influence,[attached=[],name=i213],[]).
arc(arc00114,node00117,node00122,influence,[attached=[],complete=true,name=i214,role=[use(none,in_hierarchy,usr(at_top),int)]],[curve=[13,-8]]).
arc(arc00115,node00119,node00122,influence,[attached=[],complete=true,name=i215,role=[use(none,in_hierarchy,usr(at_bottom),int)]],[curve=[-9,-13]]).
arc(arc00129,node00129,node00122,influence,[attached=[],complete=true,name=i229,role=[use(none,in_hierarchy,usr(start_bottom),int)]],[curve=[-12,25]]).
arc(arc00130,node00115,node00122,influence,[attached=[],complete=true,name=i230,role=[use(none,in_hierarchy,usr(bottom),int)]],[curve=[-14,5]]).
arc(arc00131,node00113,node00122,influence,[attached=[],complete=true,name=i231,role=[use(none,in_hierarchy,usr(top),int)]],[curve=[12,4]]).
arc(arc00330,node00140,node00122,influence,[attached=[],complete=true,name=i128,role=[use(none,in_hierarchy,usr(sublist_in),int)]],[curve=[23,5]]).
arc(arc00334,node00226,node00122,influence,[attached=[],complete=true,name=i132,role=[use(none,in_hierarchy,usr([start]),array(1,5))]],[curve=[-8,-32]]).
arc(arc00116,node00124,node00123,influence,[attached=[],name=i216],[]).
arc(arc00117,node00121,node00124,influence,[attached=[],complete=true,name=i217,role=[use(none,in_hierarchy,take_top,boolean)]],[curve=[-5,12]]).
arc(arc00118,node00117,node00124,influence,[attached=[],complete=true,name=i218,role=[use(none,in_hierarchy,usr(at_top),int)]],[curve=[7,4]]).
arc(arc00119,node00119,node00124,influence,[attached=[],complete=true,name=i219,role=[use(none,in_hierarchy,usr(at_bottom),int)]],[curve=[-14,-1]]).
arc(arc00124,node00130,node00129,influence,[attached=[],name=i224],[]).
arc(arc00141,node00140,node00130,influence,[attached=[],complete=true,name=i241,role=[use(none,in_hierarchy,usr(sublist_in),int)]],[curve=[36,-15]]).
arc(arc00318,node00139,node00130,influence,[attached=[],complete=true,name=i118,role=[use(none,in_hierarchy,usr(sublist_out),int)]],[curve=[38,-2]]).
arc(arc00321,node00216,node00215,influence,[attached=[],name=i121],[]).
arc(arc00322,node00129,node00216,influence,[attached=[],complete=true,name=i122,role=[use(none,in_hierarchy,start_bottom,int)]],[curve=[-16,13]]).
arc(arc00323,node00121,node00216,influence,[attached=[],complete=true,name=i123,role=[use(none,in_hierarchy,take_top,boolean)]],[curve=[-9,-12]]).
arc(arc00324,node00140,node00216,influence,[attached=[],complete=true,name=i124,role=[use(none,in_hierarchy,sublist_in,int)]],[curve=[15,-6]]).
arc(arc00204,node00304,node00303,influence,[attached=[],name=i4],[]).
arc(arc00205,node00123,node00304,influence,[attached=[],complete=true,name=i5,role=[use(none,in_hierarchy,out,int)]],[curve=[-11,2]]).
arc(arc00206,node00226,node00304,influence,[attached=[],complete=true,name=i6,role=[use(none,in_hierarchy,[start],array(1,5))]],[curve=[-24,-13]]).
arc(arc00208,node00303,node00305,influence,[attached=[],complete=true,name=i8],[curve=[-5,0]]).
arc(arc00133,node00136,node00135,influence,[attached=[],name=i233],[]).
arc(arc00314,node00142,node00136,influence,[attached=[],complete=true,name=i114,role=[use(none,in_hierarchy,usr(al2),boolean)],use_sofar=1],[curve=[7,-37]]).
arc(arc00315,node00137,node00136,influence,[attached=[],complete=true,name=i115,role=[use(none,in_hierarchy,usr(sublist_out),int)],use_sofar=1],[curve=[0,15]]).
arc(arc00135,node00138,node00137,influence,[attached=[],name=i235],[]).
arc(arc00136,node00135,node00138,influence,[attached=[],complete=true,name=i236,role=[use(none,in_hierarchy,usr(sublist_in),int)]],[curve=[0,-15]]).
arc(arc00146,node00143,node00142,influence,[attached=[],name=i246],[]).
arc(arc00207,node00001,node00143,influence,[attached=[],complete=true,name=i7,role=[use(none,in_hierarchy,[right],array(boolean,5))]],[curve=[-4,19]]).
arc(arc00301,node00225,node00143,influence,[attached=[],complete=true,name=i101,role=[use(none,in_hierarchy,[start],array(1,5))]],[curve=[-41,-5]]).
arc(arc00317,node00137,node00143,influence,[attached=[],complete=true,name=i117,role=[use(none,in_hierarchy,sublist_out,int)]],[curve=[1,55]]).
arc(arc00304,node00001,node00203,influence,[attached=[],complete=true,name=i104],[curve=[-6,14]]).
arc(arc00302,node00202,node00201,influence,[attached=[],name=i102],[]).
arc(arc00303,node00141,node00202,influence,[attached=[],complete=true,name=i103,role=[use(none,in_hierarchy,[out],array(int,5))]],[curve=[-3,17]]).
