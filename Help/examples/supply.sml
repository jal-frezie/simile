source(program='AME',version=6.9,date='Wed May 08 11:16:03  2002').

roots([node00002,node00003,node00004,node00005,node00006,node00007,node00008
,node00009,node00010,node00011,node00013,node00014,node00015,node00016,
node00017,node00019,node00012,node00018]).

properties([complete-true,file_name-'C:/Documents and Settings/Alastair \
Davies/My Documents/Projects/Examples/supply and demand.sml',name-'Deskt\
op']).

node(node00002,compartment,[],[complete=true,name='Stock'],[bounding_box
=[-1.2774524587999991,14.019948688900001,38.7225475412,44.0199486889],
caption_offset=[-1.8722547540999983,-17.786420164199995]]).
node(node00003,function,[],[complete=true,name=fn1,units=1,value='Desire\
d_Stock_Level'],[]).
node(node00004,cloud,[],[complete=true,name=cd1],[bounding_box=[-152.419106559
,19.82833082,-128.419106559,43.828330820000005]]).
node(node00005,function,[],[complete=true,name=fn2,units=1,value='Suppl\
y'],[]).
node(node00006,cloud,[],[complete=true,name=cd2],[bounding_box=[138.716507707
,17.0199486889,162.716507707,41.0199486889]]).
node(node00007,function,[],[complete=true,name=fn3,units=1,value='Deman\
d'],[]).
node(node00008,variable,[],[complete=true,name='Supply'],[bounding_box=[
-275.517165911,-142.47219048940002,-261.517165911,-128.47219048940002],
caption_offset=[-34.048566324999996,-17.211750397100005]]).
node(node00009,function,[],[complete=true,name=fn4,units=1,value=graph(0
,100,400,100,0,400,0,21,points(400,400,400,338,324,297,266,264,248,234,
226,197,166,125,100,75,66,53,40,21,0),'Price_level')],[]).
node(node00010,variable,[],[complete=true,name='Demand'],[bounding_box=[
107.4207521593,-130.15344872540004,121.4207521593,-116.1534487254],
caption_offset=[36.235109681,-16.883984935599983]]).
node(node00011,function,[],[complete=true,name=fn5,units=1,value=graph(0
,100,400,100,0,400,0,21,points(16,28,42,52,71,94,128,155,187,213,231,254
,270,292,309,329,343,361,373,385,400),'Price_level')],[]).
node(node00013,function,[],[name=fn6],[]).
node(node00014,compartment,[],[complete=true,name='Price level'],[
bounding_box=[-40.56784857683998,-205.00016539600003,-0.5678485768399977
,-175.00016539600003],caption_offset=[1.87225475412,-49.61475098400001]]
).
node(node00015,function,[],[complete=true,name=fn7,units=1,value=75],[])
.
node(node00016,cloud,[],[complete=true,name=cd3],[bounding_box=[
17.67738286109998,-49.04804207549996,41.6773828611,-25.048042075499993]]
).
node(node00017,function,[],[complete=true,name=fn8,units=1,value='Price_\
level'*('Desired_Stock_Level'-'Stock')/'Stock'],[]).
node(node00019,function,[],[name=fn9],[]).
node(node00012,variable,[],[complete=true,name='Desired Stock Level'],[
bounding_box=[-90.4234036974,-63.7623159178,-76.4234036974,-49.7623159178
],caption_offset=[-67.08273699390001,-16.3406667036]]).
node(node00018,function,[],[complete=true,name=fn1_0,units=int,value=100
],[]).


arc(arc00001,node00003,node00002,influence,[name=i1],[]).
arc(arc00002,node00004,node00002,flow,[complete=true,name='Production'],
[bowtie=[-71.5,19.0,-59.5,43.0],caption_offset=[-16.850292787100003,
1.8722547540999983],course=[[-2,31],[-129,31]]]).
arc(arc00003,node00005,arc00002,influence,[name=i2],[]).
arc(arc00004,node00002,node00006,flow,[complete=true,name='Consumption']
,[bowtie=[82.5,17.0,94.5,41.0],caption_offset=[-12.169655901799999,
2.8083821311999984],course=[[139,29],[38,29]]]).
arc(arc00005,node00007,arc00004,influence,[name=i3],[]).
arc(arc00006,node00009,node00008,influence,[name=i4],[]).
arc(arc00007,node00011,node00010,influence,[name=i5],[]).
arc(arc00008,node00018,node00012,influence,[name=i1_0],[]).
arc(arc00009,node00008,node00005,influence,[complete=true,name=i7,role=[
use(none,in_hierarchy,'Supply',1)]],[course=[[-70,19],[-379.69167624350007
,-58.861311806399996],[-264.203842631,-127.92332540640001]]]).
arc(arc00010,node00012,node00003,influence,[complete=true,name=i2_0,role
=[use(none,in_hierarchy,'Desired_Stock_Level',int)]],[course=[[0,13],[-
22,-38],[-77,-51]]]).
arc(arc00011,node00010,node00007,influence,[complete=true,name=i9,role=[
use(none,in_hierarchy,'Demand',1)]],[course=[[87,17],[126.68045304635004
,-49.3022918212],[114.36090609269999,-115.6045836424]]]).
arc(arc00012,node00012,node00017,influence,[complete=true,name=i3_0,role
=[use(none,in_hierarchy,'Desired_Stock_Level',int)]],[course=[[-6,-94],[
-49,-94],[-76,-59]]]).
arc(arc00016,node00015,node00014,influence,[name=i14],[]).
arc(arc00017,node00016,node00014,flow,[complete=true,name='Price rises']
,[bowtie=[-6.5,-110.0,5.5,-86.0],caption_offset=[18.9154096259,-
32.75030554899999],course=[[-25,-175],[-25,-98],[24,-98],[24,-47]]]).
arc(arc00018,node00017,arc00017,influence,[name=i15],[]).
arc(arc00021,node00002,node00017,influence,[complete=true,name=i17,role=
[use(none,in_hierarchy,'Stock',1)]],[course=[[1,-86],[-17,-32],[15,14]]]
).
arc(arc00023,node00014,node00009,influence,[complete=true,name=i19,role=
[use(none,in_hierarchy,'Price_level',1)]],[course=[[-262.203842631,-
138.9233254064],[-147.09351539850002,-233.8895239147],[-39.462065297999985
,-174.32758162300001]]]).
arc(arc00024,node00014,node00011,influence,[complete=true,name=i20,role=
[use(none,in_hierarchy,'Price_level',1)]],[course=[[108.36090609269999,-
126.6045836424],[68.94942039735001,-168.9660826327002],[-3.4620652980000006
,-174.32758162300001]]]).
arc(arc00025,node00014,node00017,influence,[complete=true,name=i21,role=
[use(none,in_hierarchy,'Price_level',1)]],[course=[[-2,-110],[7,-146],[-
16,-175]]]).
