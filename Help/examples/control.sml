source(program='AME',version=6.9,date='Sun May 12 21:34:18  2002').

roots([node00002,node00003,node00004,node00005,node00007,node00009,node00010
,node00011,node00012,node00013,node00016,node00017,node00018,node00019,
node00020,node00021,node00022,node00023,node00006,node00024,node00026,
node00027,node00028,node00031,node00032,node00014,node00048]).

properties([complete-true,file_name-'C:/Documents and Settings/Alastair \
Davies/My Documents/Projects/Examples/Process control.sml',name-'Deskto\
p']).

node(node00002,compartment,[],[complete=true,name='Temperature'],[
bounding_box=[24.8242312319,-29.4951416818,64.8242312319,0.5048583182000002
],caption_offset=[16.5124166198,-51.10986096609999]]).
node(node00003,function,[],[complete=true,name=fn1,units=1,value=25],[])
.
node(node00004,cloud,[],[complete=true,name=cd1],[bounding_box=[
199.29071103199996,-26.447417759279997,223.2907110319999,-2.4474177592799995
]]).
node(node00005,function,[],[complete=true,name=fn2,units=1,value='Heat_i\
nput'/'Heat_capacity'],[]).
node(node00007,function,[],[complete=true,name=fn3,units=1,value=0.2],[]
).
node(node00009,function,[],[name=fn4,units=1,value=var1],[]).
node(node00010,cloud,[],[complete=true,name=cd3],[bounding_box=[-133.759190127
,-23.5961133454,-109.759190127,0.40388665460000084]]).
node(node00011,function,[],[complete=true,name=fn5,units=1,value='Heat_l\
oss'/'Heat_capacity'],[]).
node(node00012,variable,[],[complete=true,name='Heat loss'],[bounding_box
=[-89.5620830991,-69.1181387126,-75.5620830991,-55.1181387126],caption_offset
=[-34.5974443459,-16.5124166198]]).
node(node00013,function,[],[complete=true,name=fn6,units=int,value=10],[
]).
node(node00016,variable,[],[complete=true,name='Heat content'],[bounding_box
=[274.49738809,72.4168608858,288.49738808999996,86.4168608858],caption_offset
=[0,0]]).
node(node00017,function,[],[complete=true,name=fn8,units=1,value=13.2],[
]).
node(node00018,variable,[],[complete=true,name='Gas flow'],[bounding_box
=[168.33189235700002,111.72738987369999,182.33189235700004,125.72738987370003
],caption_offset=[-32.23809598799998,-24.37158687]]).
node(node00019,function,[],[complete=true,name=fn9,units=1,value='Valve_\
position'*'Valve_linearity'],[]).
node(node00020,variable,[],[complete=true,name='Heat input'],[bounding_box
=[150.261110665,48.0413887327,164.261110665,62.0413887327],caption_offset
=[31.452222132999992,-22.802861046500006]]).
node(node00021,function,[],[complete=true,name=fn10,units=1,value='Gas_f\
low'*'Heat_content'],[]).
node(node00022,variable,[],[complete=true,name='Heat capacity'],[bounding_box
=[35.4371881874,-88.73088095350002,49.43718818739998,-74.7308809535],
caption_offset=[45.58068360870001,-17.289224817100006]]).
node(node00023,function,[],[complete=true,name=fn11,units=1,value=4.184]
,[]).
node(node00006,function,[],[complete=false,name=fn1_0,units=1,value=('Se\
t_point'-'Temperature')/100],[]).
node(node00024,function,[],[complete=true,max_val=1,min_val=0,name=fn2_0
,units=1,value=0],[]).
node(node00026,function,[],[complete=false,name=fn3_0,units=1,value=('Se\
t_point'-'Temperature')/100],[]).
node(node00027,variable,[],[complete=true,name='Valve linearity'],[
bounding_box=[256.26774153300005,147.031275642,270.26774153300005,
161.031275642],caption_offset=[0,0]]).
node(node00028,function,[],[complete=true,name=fn1_1,units=int,value=1],
[]).
node(node00031,variable,[],[complete=true,name='Valve position'],[
bounding_box=[172.17923901380001,197.327202384,186.1792390138,211.327202384
],caption_offset=[0,0]]).
node(node00032,function,[],[complete=true,name=fn3_1,units=1,value='Outp\
ut'],[]).
node(node00014,variable,[],[complete=true,max_val=100,min_val=0,name='Se\
t point',units=1,value=65],[bounding_box=[-95.06233669029999,36.27572919909999
,-81.06233669029999,50.27572919909997],caption_offset=[-33.811138793,-
16.51241661990001]]).
node(node00048,submodel,[node00008,node00029,node00030,node00033,node00034
,node00035,node00036,node00037,node00039,node00041,node00043,node00044,
node00045,node00046,node00049,node00050,node00051],[complete=true,fill_colour
='#ffff00',fix_math_args=0,multiplication_spec=[count=[]],name='PID cont\
roller',separate=0],[bounding_box=[-187.037977567,79.3732593875,114.737582877
,256.98075069],caption_offset=[29.07733264699999,-7.072864697900002],
hide_contents=0,internal_extent=[0,0,301.775560444,177.60749130249997]])
.
links(node00048,[arc00024-arc00010,arc00024-arc00026,arc00027-arc00025,
arc00028-arc00023]).
node(node00008,variable,[],[name=var1],[]).
node(node00029,variable,[],[complete=true,name=e],[bounding_box=[
147.8171494988,32.29369276649999,161.8171494988,46.29369276649999],
caption_offset=[-17.025969256100012,-21.755405161000013]]).
node(node00030,function,[],[complete=true,description='Error',name=fn2_1
,units=1,value='Temperature'-'Set_point'],[]).
node(node00033,compartment,[],[complete=true,name='Integral Error'],[
bounding_box=[38.154665295000015,111.52569070749999,78.15466529500002,
141.5256907075],caption_offset=[-7.567097446999995,-0.9458871809999891]]
).
node(node00034,function,[],[complete=true,description='Integral error',
name=fn4_0,units=1,value=0],[]).
node(node00035,cloud,[],[complete=true,name=cd1_0],[bounding_box=[
38.29592674100002,24.93607120049998,62.29592674100002,48.93607120049998]
]).
node(node00036,function,[],[complete=true,name=fn5_0,units=1,value='Erro\
r'],[]).
node(node00037,variable,[],[complete=true,description='Integral time',
max_val=50,min_val=0,name='Ti',units=1,value=25],[bounding_box=[
96.73534890290001,136.02904166849999,110.73534890290006,150.02904166849999
],caption_offset=[0,0]]).
node(node00039,variable,[],[complete=true,description='Derivative time',
max_val=50,min_val=0,name='Td',units=1,value=5],[bounding_box=[251.6983189544
,38.260656957500004,265.6983189544,52.260656957500004],caption_offset=[
19.98106580669996,-13.228227759999982]]).
node(node00041,variable,[],[complete=true,description='Controller gain',
max_val=0,min_val= -0.05,name='P',units=1,value= -0.025],[bounding_box=[
154.94678528669996,63.20602868549997,168.94678528669996,77.20602868549997
],caption_offset=[-16.908534248229984,-20.098500815000023]]).
node(node00043,variable,[],[complete=true,name='Output'],[bounding_box=[
235.8350212949,125.81268154949998,249.8350212949,139.81268154949998],
caption_offset=[0,0]]).
node(node00044,function,[],[comment='The traditional form of the PIC equ\
ation',complete=true,description='Controller output',name=fn9_0,units=1,
value='P'*(e+'IE'/'Ti'-'Td'*dPV)],[]).
node(node00045,variable,[],[complete=true,name=dPV],[bounding_box=[
229.7222365504,19.559697754499993,243.7222365504,33.55969775449999],
caption_offset=[22.80453457690001,-16.983390939000003]]).
node(node00046,function,[],[complete=true,description='Rate of change of\
 process variable',name=fn10_0,units=1,value='Temperature'-last('Tempera\
ture')],[]).
node(node00049,variable,[],[],[]).
node(node00050,variable,[],[],[]).
node(node00051,variable,[],[],[]).


arc(arc00001,node00003,node00002,influence,[name=i1],[]).
arc(arc00002,node00004,node00002,flow,[complete=true,name='Heating'],[
bowtie=[126.0,-26.0,138.0,-2.0],caption_offset=[11.794583300000028,-
32.23852768619999],course=[[64,-14],[200,-14]]]).
arc(arc00003,node00005,arc00002,influence,[name=i2],[]).
arc(arc00004,node00028,node00027,influence,[name=i1_0],[]).
arc(arc00005,node00027,node00019,influence,[complete=true,name=i2_0,role
=[use(none,in_hierarchy,'Valve_linearity',int)]],[course=[[181,120],[210
,154],[256,151]]]).
arc(arc00006,node00030,node00029,influence,[name=i3],[]).
arc(arc00007,node00002,node00010,flow,[complete=true,name='Cooling'],[
bowtie=[-50.5,-26.0,-38.5,-2.0],caption_offset=[6.290444426600001,-
10.235354831350001],course=[[-113,-14],[24,-14]]]).
arc(arc00008,node00011,arc00007,influence,[name=i5],[]).
arc(arc00009,node00013,node00012,influence,[name=i6],[]).
arc(arc00010,node00008,node00046,influence,[complete=true,name=i1,role=[
use(none,in_hierarchy,'Temperature',1)]],[course=[[229,22],[214,0],[
189.037977567,-0.3732593875000134]]]).
arc(arc00011,node00017,node00016,influence,[name=i8],[]).
arc(arc00012,node00019,node00018,influence,[name=i9],[]).
arc(arc00013,node00021,node00020,influence,[name=i10],[]).
arc(arc00014,node00023,node00022,influence,[name=i11],[]).
arc(arc00015,node00012,node00011,influence,[complete=true,name=i12,role=
[use(none,in_hierarchy,'Heat_loss',int)]],[course=[[-50,-21],[-54,-45],[
-77,-56]]]).
arc(arc00016,node00022,node00011,influence,[complete=true,name=i13,role=
[use(none,in_hierarchy,'Heat_capacity',1)]],[course=[[-38,-18],[13,-28],
[36,-76]]]).
arc(arc00017,node00022,node00005,influence,[complete=true,name=i14,role=
[use(none,in_hierarchy,'Heat_capacity',1)]],[course=[[126,-18],[101,-66]
,[47,-76]]]).
arc(arc00018,node00020,node00005,influence,[complete=true,name=i15,role=
[use(none,in_hierarchy,'Heat_input',1)]],[course=[[136,-2],[132,27],[154
,48]]]).
arc(arc00020,node00016,node00021,influence,[complete=true,name=i17,role=
[use(none,in_hierarchy,'Heat_content',1)]],[course=[[163,56],[213,94],[
274,77]]]).
arc(arc00021,node00018,node00021,influence,[complete=true,name=i18,role=
[use(none,in_hierarchy,'Gas_flow',1)]],[course=[[158,61],[153,89],[173,
111]]]).
arc(arc00023,node00048,node00032,influence,[complete=true,name=i24,role=
[use(none,in_hierarchy,'Output',1)]],[course=[[172,204],[142,191],[114,
207]]]).
arc(arc00024,node00002,node00048,influence,[complete=true,name=i5_1,role
=[use(none,in_hierarchy,'Temperature',1)]],[course=[[2,79],[39,48],[37,1
]]]).
arc(arc00025,node00049,node00030,influence,[complete=true,name=i4_0,role
=[use(none,in_hierarchy,'Set_point',1)]],[course=[[151,32],[153,13],[
140.037977567,-0.3732593875000134]]]).
arc(arc00026,node00050,node00030,influence,[complete=true,name=i5_1,role
=[use(none,in_hierarchy,'Temperature',1)]],[course=[[158,33],[181,24],[
189.037977567,-0.3732593875000134]]]).
arc(arc00027,node00014,node00048,influence,[complete=true,name=i4_0,role
=[use(none,in_hierarchy,'Set_point',1)]],[course=[[-47,79],[-56,54],[-82
,47]]]).
arc(arc00028,node00043,node00051,influence,[complete=true,name=i24,role=
[use(none,in_hierarchy,'Output',1)]],[course=[[301.037977567,127.62674061249999
],[273,116],[248,131]]]).
arc(arc00029,node00032,node00031,influence,[name=i6_0],[]).
arc(arc00030,node00031,node00019,influence,[complete=true,name=i7_0,role
=[use(none,in_hierarchy,'Valve_position',1)]],[course=[[175,124],[158,161
],[178,197]]]).
arc(arc00031,node00034,node00033,influence,[name=i8_0],[]).
arc(arc00032,node00035,node00033,flow,[complete=true,name=flow1],[bowtie
=[38.0,72.5,62.0,84.5],caption_offset=[-50.2959267408,-19.646846383000025
],course=[[50,111],[50,46]]]).
arc(arc00033,node00036,arc00032,influence,[name=i9_0],[]).
arc(arc00034,node00029,node00036,influence,[complete=true,name=i10_0,role
=[use(none,in_hierarchy,'Error',1)]],[course=[[62,73],[112,78],[147,41]]
]).
arc(arc00039,node00044,node00043,influence,[name=i15_0],[]).
arc(arc00040,node00033,node00044,influence,[complete=true,name=i16,role=
[use(none,in_hierarchy,'IE',1)]],[course=[[235,131],[157,89],[78,126]]])
.
arc(arc00041,node00037,node00044,influence,[complete=true,name=i17_0,role
=[use(none,in_hierarchy,'Ti',1)]],[course=[[235,132],[169,105],[109,142]
]]).
arc(arc00042,node00041,node00044,influence,[complete=true,name=i18_0,role
=[use(none,in_hierarchy,'P',1)]],[course=[[236,127],[214,83],[166,74]]])
.
arc(arc00043,node00029,node00044,influence,[complete=true,name=i19,role=
[use(none,in_hierarchy,e,1)]],[course=[[237,126],[218,65],[158,44]]]).
arc(arc00044,node00039,node00044,influence,[complete=true,name=i20,role=
[use(none,in_hierarchy,'Td',1)]],[course=[[243,125],[268,91],[256,51]]])
.
arc(arc00045,node00046,node00045,influence,[name=i21],[]).
arc(arc00047,node00045,node00044,influence,[complete=true,name=i23,role=
[use(none,in_hierarchy,dPV,1)]],[course=[[241,125],[261,77],[236,32]]]).
