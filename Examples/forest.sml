source(program='AME',version=7.0,edition=standard,date='Mon Dec 09 14:21:45 GMT Standard Time 2002').

roots([node00008,node00018,node00019,node00020]).

properties([complete-true,file_name-'C:/Documents and Settings/Alastair Davies/My Documents/Projects/Examples/Forest Tree Growth.sml',name-'Desktop']).

node(node00008,submodel,[node00002,node00003,node00004,node00005,node00006,node00007,node00009,node00010,node00011,node00012,node00013,node00014,node00015,node00016,node00017,node00021,node00022],[complete=true,fill_colour='#00ff00',fix_math_args=0,multiplication_spec=[type=population],name='Tree',separate=0],[bounding_box=[-23.840693871000013,14.0634445787,367.71935102199996,200.8558127046],caption_offset=[23.97306397300001,-12.985409652100003],hide_contents=0,internal_extent=[-5.11590769747273e-013,-2.2737367544323246e-013,391.56004489300017,186.7923681259001]]).
links(node00008,[arc00012-arc00014]).
node(node00002,compartment,[],[complete=true,name='Tree Size'],[bounding_box=[283.658810325,81.8911335578,323.658810325,111.8911335578],caption_offset=[0,0]]).
node(node00003,function,[],[complete=true,description='Tree size',name=fn1,spec=[48],units=1,value=0],[]).
node(node00004,cloud,[],[complete=true,name=cd1],[bounding_box=[86.88888888870004,84.8911335578,110.88888888870004,108.8911335578]]).
node(node00005,function,[],[complete=true,name=fn2,units=1,value=max(var1-comp1^1.1,0)],[]).
node(node00006,variable,[],[complete=true,name='Maximum Growth Rate'],[bounding_box=[137.83726150370003,38.948372615000004,151.83726150370003,52.948372615000004],caption_offset=[-26.96969696970001,-33.961840628556]]).
node(node00007,function,[],[complete=true,name=fn3,spec=[50,50],units=int,value=22],[]).
node(node00009,loss,[],[complete=true,name='Chance of Death'],[bounding_box=[329.612794613,14.966329966300002,359.612794613,44.9663299663],caption_offset=[0,0]]).
node(node00010,function,[],[complete=true,name=fn4,units=1,value=0.1],[]).
node(node00011,immigration,[],[complete=true,name='Saplings'],[bounding_box=[23.95622895610005,124.84287317619999,53.95622895610005,154.8428731762],caption_offset=[0,0]]).
node(node00012,function,[],[complete=true,name=fn5,units=int,value=5],[]).
node(node00013,variable,[],[complete=true,name='X Position'],[bounding_box=[129.84624017935002,143.83052749720002,143.84624017935002,157.83052749720002],caption_offset=[0,0]]).
node(node00014,function,[],[complete=true,description='X-coordinate of tree',name=fn6,spec=[114,97,110,100,95,99,111,110,115,116,40,48,44,49,48,48,41],units=1,value=rand_const(0,100)],[]).
node(node00015,variable,[],[complete=true,name='Y Position'],[bounding_box=[202.76430976410003,142.8316498316,216.76430976410003,156.8316498316],caption_offset=[0,0]]).
node(node00016,function,[],[complete=true,description='Y-coordinate of tree',name=fn7,spec=[114,97,110,100,95,99,111,110,115,116,40,48,44,49,48,48,41],units=1,value=rand_const(0,100)],[]).
node(node00017,variable,[],[complete=true,name='ID'],[bounding_box=[300.534565037,153.87250842970002,314.534565037,167.87250842970005],caption_offset=[-18.089638901,-16.393735254100022]]).
node(node00021,function,[],[complete=true,name=fn1_0,spec=[105,110,100,101,120,40,49,41],units=int,value=index(1)],[]).
node(node00022,variable,[],[name=var2],[]).
node(node00018,function,[],[complete=false,name=fn8],[]).
node(node00019,variable,[],[complete=true,name='Number of Trees'],[bounding_box=[352.3182232930001,236.61954278100006,366.31822329300013,250.61954278100006],caption_offset=[0,0]]).
node(node00020,function,[],[complete=true,name=fn9,spec=[99,111,117,110,116,40,123,73,68,125,41],units=int,value=count({'ID'})],[]).


arc(arc00001,node00003,node00002,influence,[name=i1],[]).
arc(arc00002,node00004,node00002,flow,[complete=true,name='Growth Rate'],[bowtie=[190.85521885500003,83.9259259259,202.85521885500003,107.9259259259],caption_offset=[-13.984287317699994,1.9977553310999951],course=[[282.85521885500003,95.9259259259],[110.85521885500003,95.9259259259]]]).
arc(arc00003,node00005,arc00002,influence,[name=i2],[]).
arc(arc00006,node00002,node00005,influence,[complete=true,name=i5,role=[use(none,in_hierarchy,comp1,1)]],[course=[[202.85521885500003,95.9259259259],[276.81705948300004,135.9034792367],[282.85521885500003,95.9259259259]]]).
arc(arc00005,node00006,node00005,influence,[complete=true,name=i4,role=[use(none,in_hierarchy,var1,int)]],[course=[[190.85521885500003,89.9259259259],[178.85521885500003,60.9259259259],[148.85521885500003,51.9259259259]]]).
arc(arc00004,node00007,node00006,influence,[name=i3],[]).
arc(arc00007,node00010,node00009,influence,[name=i6],[]).
arc(arc00009,node00012,node00011,influence,[name=i8],[]).
arc(arc00010,node00014,node00013,influence,[name=i9],[]).
arc(arc00011,node00016,node00015,influence,[name=i10],[]).
arc(arc00008,node00021,node00017,influence,[name=i1_0],[]).
arc(arc00012,node00017,node00022,influence,[complete=true,name=i2_0],[course=[[342.8364509062158,186.7923681259001],[337.5996793814887,156.1847954256461],[314.9450293879412,159.7170785947773]]]).
arc(arc00013,node00020,node00019,influence,[name=i12],[]).
arc(arc00014,node00008,node00020,influence,[complete=true,name=i3,role=[use(none,in_hierarchy,{'ID'},list(int))]],[course=[[355.5286568476202,237.14735720300163],[338.33544134260745,207.78313228840008],[318.99575703521566,200.8558127046]]]).
