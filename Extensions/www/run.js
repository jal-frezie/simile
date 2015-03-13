var tabs;
	$(function() {
		
	    $( "#button" ).button();
	    $( "#radioset" ).buttonset();
		
	    tabs = $( "#tabs" ).tabs({heightstyle:"fill"});
	    tabs.tabs({
		activate: function( event, ui ) {
		    if (ui.newPanel.selector != "#tabs-1") { // diagram
			currentHelper = currentHelpers[$(ui.newPanel.selector)[0].id];
		    }
		}
	    });
// close icon: removing the tab on click
tabs.delegate( "span.ui-icon-close", "click", function() {
  var panelId = $( this ).closest( "li" ).remove().attr( "aria-controls" );
  delete currentHelpers[panelId];
  $( "#" + panelId ).remove();
  tabs.tabs( "refresh" );
});

		

		

		

		
		$( "#progress" ).progressbar({
			value: 0
		});
		

		// Hover states on the static widgets
		$( "#dialog-link, #icons li" ).hover(
			function() {
				$( this ).addClass( "ui-state-hover" );
			},
			function() {
				$( this ).removeClass( "ui-state-hover" );
			}
		);
	});

function hoverIn(evt) {
  var tags = null;
  var blob = evt.target;
  while (tags == null) {
    tags = blob.getAttribute("id");
    blob = blob.parentNode;
  }
  var prolog = tags.match(/arc\d\d\d\d\d|node\d\d\d\d\d/);
//  var currentLine = model_json.find(function (e) {
//		     return e.id == prolog;
// 		     });
  tooltip_q.firstChild.data = model_json[prolog].equation;
  tooltip_v.firstChild.data = values_json[prolog];
// above will break function if it doesn't work

        var uupos = ModDiag.createSVGPoint();
        uupos.x = evt.pageX - window.pageXOffset;
        uupos.y = evt.pageY - window.pageYOffset;
        var ctm = ModDiag.getScreenCTM();
        if (ctm = ctm.inverse())
            uupos = uupos.matrixTransform(ctm);

  tooltip_grp.setAttributeNS(null,"transform",
			     "translate(" + uupos.x + "," + uupos.y + ")scale("
			     + tooltip_scale + ")");
  tooltip_bd.setAttributeNS(null,"visibility","visible");
  tooltip_qbg.setAttribute("visibility", "visible");
  tooltip_vbg.setAttribute("visibility", "visible");
  tooltip_q.setAttributeNS(null,"visibility","visible");
  tooltip_v.setAttributeNS(null,"visibility","visible");

  length = Math.max(tooltip_q.getComputedTextLength(),
		     tooltip_v.getComputedTextLength());
  tooltip_bd.setAttributeNS(null,"width",length+8);
  tooltip_qbg.setAttributeNS(null,"width",length+8);
  tooltip_vbg.setAttributeNS(null,"width",length+8);
}

function hoverOut() {
  tooltip_bd.setAttributeNS(null,"visibility","hidden");
  tooltip_qbg.setAttribute("visibility", "hidden");
  tooltip_vbg.setAttribute("visibility", "hidden");
  tooltip_q.setAttributeNS(null,"visibility","hidden");
  tooltip_v.setAttributeNS(null,"visibility","hidden");
}

function addHoverAction(comp) {
  comp.addEventListener("mouseover", hoverIn);
  comp.addEventListener("mouseout", hoverOut);
}

function tclListOfDimty(stuff, n) {
    if (n==0) {
	return stuff;
    }
    if (!(stuff.constructor === Array)) {
	return [tclListOfDimty(stuff, n-1)];
    }
    var result = [];
    for (var i=0; i<stuff.length; ++i) {
	result.push(tclListOfDimty(stuff[i],n-1));
    }
    return result;
}

function idFromCapt (capt) {
    for (comp in model_json) {
	if (model_json[comp].captpath == capt) {
	    return model_json[comp].id;
	}
    }
}

function addTabFor(tclInst) {
    convd = tclInst.textContent.replace(/}*\s+{*/g,"\"$&\"")
	.replace(/{/g,"[").replace(/}/g,"]").replace(/\s+/g,", ")
    specArray = JSON.parse("["+convd.substr(3,convd.length-6)+"]");
    species = tclInst.attributes.type.value;
//    console.log("Helper key "+species+", state "+JSON.stringify(specArray));

    switch (species) {
	case "plotter1_dot_25":
	new_helper("plot");
	captArr = specArray[specArray.indexOf("/WIN/,Yvars")+1];
	captPath0 = tclListOfDimty(captArr,2)[0].join(" ");
//	console.log("Adding plot of " + captPath0);
// now boringly find this by iteration
	select_for_helper(idFromCapt(captPath0));
	select_for_helper("time");
// add more if helper can display multiple plotz
	break;

	case "tabular11510":
	new_helper("table");
	captPaths = tclListOfDimty(specArray[0], 2);
	for (var i=0; i<captPaths.length; ++i) {
	    captPath = captPaths[i].join(" ");
// now boringly find this by iteration
	    for (comp in model_json) {
		if (model_json[comp].captpath == captPath) break;
	    }
	    select_for_helper(model_json[comp].id);
	}
	break;

	case "gen3d1": // lollipops
	new_helper("shapes");
	var i=3;
	while (specArray[i] != "/annotation/") {
	    AddItem(currentHelper, "lollipops");
	    for (parm in {"x":0,"y":0,"h":0}) {
		captPath = tclListOfDimty(specArray[i++],1).join(" ");
		for (comp in model_json) {
		    if (model_json[comp].captpath == captPath) break;
		}
		currentHelper.acceptClick(comp);
	    }
	    
	}
	break;

	case "slide139":
	new_helper("sliders");
	break;

	case "plotterXY1_dot_0":
	new_helper("plot");
	captArr = specArray[specArray.indexOf("/WIN/,Yvars")+1];
	captPath = tclListOfDimty(captArr,1).join(" ");
//	console.log("Adding plot of " + captPath0);
// now boringly find this by iteration
	select_for_helper(idFromCapt(captPath));
	captArr = specArray[specArray.indexOf("/WIN/,Xvars")+1];
	captPath = tclListOfDimty(captArr,1).join(" ");
//	console.log("Adding plot of " + captPath0);
// now boringly find this by iteration
	select_for_helper(idFromCapt(captPath));
	break;

	case "Shapes3D20141208":
	new_helper("shapes");
	currentHelper.State = specArray;
// would be done, but must convert capt paths to node ids
	for (var i=0; i<specArray.length;++i) {
	    for (var j=0; j<specArray[i].length;++j) {
		possCapt = tclListOfDimty(specArray[i][j], 1);
		if (possCapt[0][0] == "/") { // its a capt path
		    nodeId = idFromCapt(possCapt.join(" "));
		    currentHelper.State[i][j] = nodeId;
		    currentHelper.tgts.push(nodeId);
		} else if (possCapt[0][0] == "#") { // it's a colour
		    currentHelper.State[i][j] = possCapt[0].substr(1);
		}
	    }
	}
	break;
	default:
	console.log("Cannot emulate Tcl helper: " + species);
    }
}

function createInitialHelpers() {
// convert Simile XML-style helper setup into a set of tabs on the client

// First get the XML from the server
    $.ajax({
	type: "POST",
	url: "model_action.php",
	data: { "base":fileBase, "act":"GetXMLHelperSetup"}
    })
	.done(function( returnedXML ) {
	    if (returnedXML == '') return;
	    parser=new DOMParser();
	    hlpDoc=parser.parseFromString(returnedXML,"text/xml");
	    if ($(hlpDoc).find("parsererror").length > 0) {
		alert("Helper setup file failed to parse as XML");
		return;
	    }
	    tclHelpers = $(hlpDoc).find("container");
	    for (var i=0; i<tclHelpers.length; ++i) {
		addTabFor(tclHelpers[i]);
	    }
// resize in case rows of tabs have squeezed panes
	    resize_notebook();
	});
}

/*
  Zoom now uses d3 sorcery
  function SvgDiagZoom(factor) {
  ModDiag.setAttribute("width",factor*ModDiag.getAttribute("width"));
  ModDiag.setAttribute("height",factor*ModDiag.getAttribute("height"));
  }
*/
var resetDepth = -2, savedStart;
function model_reset() {
    $.ajax({
	type: "POST",
	url: "model_action.php",
	data: { "base":fileBase, "act":"Reset", "runlength":$("#rl").val()*timeUnit, 
		"current":0, "step":$("#ts").val()*timeUnit,
		"method":pipeBits.intMethod, "note":resetDepth}
    })
	.done(function( feedback ) {
	    if (feedback != '1') {
		alert(feedback);
		return;
	    }
	    if (savedStart != null) {
		$("#rl").val(parseFloat($("#rl").val())+parseFloat($("#ct").val())
			     -savedStart);
	    }
	    $("#ct").val(0);
	    $( "#progress" ).progressbar({ value: 0 });

	    $.post('model_action.php', { "base":fileBase, "act":"Report"}, 
		   function(data) {
		       values_json = JSON.parse(data);
		       latest = {}
		       oi = ofInterest();
		       for (var i in oi) {
			   latest[oi[i]] = JSON.parse(values_json[oi[i]]);
		       }
		       update_helpers(0, latest, false);
		       // now, if this is initialization, then now is the time to set up the helpers
		       // from the .shf, as they will not be expecting an immediate update
		       if (resetDepth == -2) {
			   createInitialHelpers();
		       }
		       resetDepth = 0;
		   });
	});
}

function model_step(current, start, end, span, note) {
    if (current >= end || savedStart != null) {
	// we are done, reset progress bar and update values
	$.post('model_action.php', { "base":fileBase, "act":"Report"}, 
	       function(data) {
		   values_json = JSON.parse(data);
	       });
	goImage = document.getElementById("button_op");
	goImage.src = "images/play.gif";
	goImage.parentNode.onclick = function () { model_exec(); };
	if (current < end) {
	    savedStart = start;
	    return;
	}
	newRemain = end - start;
	newProgress = 0;
	savedStart = null;
    } else {
	log = parseFloat($("#le").val());
	interval = Math.min(end-current,span);
	newCurrent = current+interval;
	newRemain = end-newCurrent;
	execParms = {"base":fileBase, "act":"ExecuteMulti",
		     "runlength":interval*timeUnit, "current":current*timeUnit,
		     "step":$("#ts").val()*timeUnit,"method":pipeBits.intMethod,
		     "log":log*timeUnit, "note":JSON.stringify(note)};
	// console.log(JSON.stringify(execParms));
	$.ajax({
	    type: "POST",
	    url: "model_action.php",
	    data: execParms})

	    .done(function(newVals) {
		// console.log('Data returned ' + newVals);
// now, process the values while fetching the next lot
		model_step(newCurrent, start, end, span, note);

		var execHistory = JSON.parse(newVals);
		for (var timePt in execHistory) {
		    var timeVal = parseFloat(timePt)/timeUnit;
		    console.log("Displaying results for time " + timeVal);
		    allResults = {};
		    for (var i=0; i<note.length;i++) {
			if (note[i].constructor === Object) {
			    resIndx = JSON.stringify(note[i]);
			} else {
			    resIndx = note[i];
			}
			allResults[resIndx] = execHistory[timePt][i];
		    }
		    update_helpers(timeVal, allResults, true);
		    // for no very obvious reason the updates are
		    // happening in the right order (at least with
		    // positive timesteps) but nothing appears on the
		    // screen till all are done -- need setTimeout.
		}
	    });
	$("#ct").val(newCurrent);
	newProgress = 100*(newCurrent-start)/(end-start);
    }
    $("#rl").val(newRemain);
    $( "#progress" ).progressbar({
	value: newProgress
    });
}

function model_pause() {
    savedStart = -999;
}

function model_exec() {
    goImage = document.getElementById("button_op");
    goImage.src = "images/pause.gif";
    now = parseFloat($("#ct").val());
    if (savedStart == null) {
	start = now;
    } else {
	start = savedStart;
	savedStart = null;
    }
    goImage.parentNode.onclick = function () { model_pause(); };
    end = now+parseFloat($("#rl").val());
    span = $("#ue").val()
    //  calibrate_helpers(end);
    model_step(now, start, end, span, ofInterest());
}

function ofInterest() {
    // list the ids of all the nodes currently being displayed by tools
    result = [];
    for (var id in currentHelpers) {
	if (currentHelpers[id].status == "displaying") {
	    for (j=0; j<currentHelpers[id].tgts.length; j++) {
		result[JSON.stringify(currentHelpers[id].tgts[j])] = 1;
	    }
	}
    }
    //  return Object.getOwnPropertyNames(result);
    // includes "length" which we don't want
    rList = [];
    for (var slot in result) {
	rList.push(JSON.parse(slot));
    }
    return rList;
}
/*
// placeholder graph plot

var pgplot_data = {
"xScale": "time",
"yScale": "linear",
"type": "line",
"main": [
{
"className": ".pizza",
"data": []
}
]
};
var pgplot_opts = {
"dataFormatX": function (x) { return d3.time.format('%j').parse(x); },
"tickFormatX": function (x) { return d3.time.format('%x')(x); }
};
*/
// actual addTab function: adds new tab using the input from the form above
var helperTitles = {"plot":"Plotter","table":"Data table",
		    "sliders":"Input sliders","params":"File parameters",
		    "shapes":"3-D shape viewer","grid":"Spatial grid"},
tabTemplate = "<li><a href='#{href}'>#{label}</a> <span class='ui-icon ui-icon-close' role='presentation'>Remove Tab</span></li>",
tabCounter = 2;

function new_tab(label) {
    id = "tabs-" + tabCounter++,
    li = $( tabTemplate.replace( /#\{href\}/g, "#" + id ).replace( /#\{label\}/g, label ) ),
    tabs.find( ".ui-tabs-nav" ).append( li );
    tabs.append( "<div id='" + id + "'></div>" );
    tabs.tabs( "refresh" );
    return(id);
}

var currentHelpers = {};
var currentHelper = null;
function new_helper(type) {
    var label = helperTitles[type];
    id = new_tab(label);
    if (type == "params") {
	currentHelper = new FileParams(id);
    } else if (type == "sliders") {
	currentHelper = new Sliders(id);
    } else if (type == "table") {
	currentHelper = new DataTable(id);
    } else if (type == "shapes") {
	currentHelper = new Shapes3D(id);
    } else if (type == "plot") {
	currentHelper = new PlotXY(id);
    } else if (type == "grid") {
	currentHelper = new Grid5(id);
    }
    currentHelpers[id] = currentHelper;
    tabs.tabs("option", "active", tabs.children().length - 2);
}

function update_helpers(time, latest, connect) {
    for (var id in currentHelpers) {
	//	try {
	currentHelpers[id].display(time, latest, connect);
	//	}
	//	catch(err) {
	//	    console.log(err);
	//	}
    }
}

function notebookPaneHeight() {
    return $("#tabs").height()-$("#tabs").find("UL").height();
}

var tooltip_scale;
function resize_notebook() {
//    console.log('Window resized');
    var x = parseInt(d3.select('#tabs').style('width'));
    var y = notebookPaneHeight();

    ModDiag.setAttribute("width", x-60);
    ModDiag.setAttribute("height",y-60);

// Get height of explorer pane right
    var height = document.getElementById('Left').clientHeight;
    var headheight = document.getElementById('RunControl').clientHeight;
    var content = document.getElementById('explorer');
    
    var availableheight = (height - headheight);
    content.style.height = availableheight + 'px';

// do something to scale tooltip_grp so popup is legible
    tooltip_scale = Math.max(ModDiag.viewBox.baseVal.width/x, 
			     ModDiag.viewBox.baseVal.height/y);
    for (var id in currentHelpers) {
	try {
	    currentHelpers[id].resize(x,y);
	}
	catch(err) {
	    console.log(err);
	}
    }
}
window.onresize = function() {resize_notebook()};

function select_for_helper(compId) {
  if (currentHelper != null) {
    currentHelper.acceptClick(compId);
  }
}

function HtmlEncode(s)
{
  var el = document.createElement("div");
  el.innerText = el.textContent = s;
  s = el.innerHTML;
  return s;
}

function AddParamLineTo(parmTable, id, ParmTree, tool) {
 divis = ParmTree.indexOf("/", 1);
 if (divis>-1) {
    subParm = ParmTree.slice(1, divis);
    rows = $(parmTable).children("TBODY").children("[name='" + subParm + "']");
    if (rows.length) {
      cell = rows[0].firstChild;
      subParmTable = cell.firstChild;
    } else {
      row = parmTable.insertRow(-1);
      hdr = document.createElement('th');
      row.appendChild(hdr);
      if (tool == "slider") {
	  tabWidth = 3;
      } else {
	  tabWidth = 2;
      }
      hdr.colSpan = tabWidth;
      hdr.innerHTML = subParm;
      row = parmTable.insertRow(-1);
	row.setAttribute("name",subParm);
      cell = row.insertCell(-1);
      cell.colSpan = tabWidth;
      subParmTable = document.createElement("TABLE");
      subParmTable.setAttribute("border", 2);
      cell.appendChild(subParmTable);
    }
    return AddParamLineTo(subParmTable, id, ParmTree.slice(divis), tool);
  } else {
    row = parmTable.insertRow(-1);
    cell = row.insertCell(-1);
    label = document.createElement("LABEL");
    cell.appendChild(label);
    label.innerHTML = ParmTree.slice(1);
    cell = row.insertCell(-1);
    input = document.createElement("INPUT");
    cell.appendChild(input);
    if (tool == "slider") {
	min = model_json[id].min;
	max = model_json[id].max;
	input.insertAdjacentHTML('beforebegin', min);
	input.setAttribute("min", 100*min);
	input.insertAdjacentHTML('afterend', max);
	input.setAttribute("max", 100*max);
	cell = row.insertCell(1);
	monitor = document.createElement("INPUT");
	monitor.setAttribute("type", "text");
        uniq = 'mtr_' + id;
	monitor.setAttribute("id", uniq);
	cell.appendChild(monitor);

	input.setAttribute("type", "range");
	input.value = values_json[id];
	transfer(input, uniq);
        cb = new Function("zap", "transfer(zap.target, '" + uniq + "');");
	input.addEventListener("input", cb);
	cb = new Function("zap", "toModel(zap.target, '" + id + "');");
	input.addEventListener("change", cb);
    } else {
	input.setAttribute("type", "text");
    }
    return input;
  }
}      

function transfer(zapTgt, entry) {
//    alert("zap " + zapTgt + " entry " + entry);
    document.getElementById(entry).value = zapTgt.value/100;
}

function toModel(zapTgt, id) {
    parmBlock = {};
    parmBlock[model_json[id].captpath] = 'NOW ' + zapTgt.value/100;
    sendValues(parmBlock);
}

function Sliders (port) {
  this.port = port;
  this.tgts = [];
  this.status = "passive";

// Add a slider for each input deprecatedly using table for layout
    $('#' + this.port).html("<table id='slidertab' border='2'></table>");
  rangeTable = document.getElementById("slidertab"); // assume only one
  for (i=0;i<fvParms.length;i++) {
      id = fvParms[i];
      if (model_json[id].eval == "INPUT") {
	  input = AddParamLineTo(rangeTable, id, model_json[id].captpath, 
				 "slider");
	  input.setAttribute("id", 'rng_' + id);
      }
  }
}

Sliders.prototype.display = function  (time, latest, connect) {
}

function FileParams (port) {
// Call the parent constructor
//   DisplayTool.call(this);

  this.port = port;
  this.tgts = [];
  this.status = "passive";
// OK now add the table to the new tab
    $('#' + this.port).html("<table id='paramtab' border='2'></table><button type='button' onclick='loadParams()'>Load</button>");
  parmTable = document.getElementById("paramtab");
  for (i=0;i<fvParms.length;i++) {
    id = fvParms[i];
    input = AddParamLineTo(parmTable, id, model_json[id].captpath, "entry");
    input.setAttribute("id", 'prm_' + id);
  }
}

FileParams.prototype.display = function  (time, latest, connect) {
}

// FileParams.prototype = new DisplayTool(this);
// FileParams.prototype.constructor = new FileParams;

// eventually this will inherit from a generic display tool class
// (when such a thing works in JS)
function DataTable (port) {
// Call the parent constructor
//   DisplayTool.call(this);

  this.port = port;
  this.tgts = [];
  this.cumData = [];
  this.columns = [];
  this.columns.push({"sTitle":"Time","mData":"time"});
  this.status = "displaying";
  this.timeRowIds = {};
  this.varColIds = {};
// OK now add the message to the new tab
  myRef = 'currentHelpers["' + port + '"]'
  $('#' + port).html("<table id='" + this.port + "_table'></table>");
}

// DataTable.prototype = new DisplayTool(this);
// DataTable.prototype.constructor = new DataTable;
DataTable.prototype.acceptClick = function (compId) {
// add its current value
  now = $("#ct").val();
  if (now in this.timeRowIds) {
    newLine = this.cumData[this.timeRowIds[now]];
  } else {
    this.timeRowIds[now] = this.cumData.length;
    newLine = {"time":now};
    this.cumData.push(newLine);
  }
  newLine[compId] = values_json[compId];
  this.tgts.push(compId);
  this.columns.push({"sTitle":model_json[compId].text,"mData":compId,
		     "sDefaultContent":"--"});
  if ('t' in this) {
    this.t.fnDestroy();
    this.t.empty();
  }
    h = notebookPaneHeight()-275;
  this.t = $('#' + this.port + "_table").dataTable({"data":this.cumData,
				       "columns":this.columns,
        "scrollY": h,
        "scrollCollapse": true,
        "paging": false,
        "jQueryUI": true});
}

DataTable.prototype.display = function(time, latest, connect) {
  if (time in this.timeRowIds) {
    newLine = this.cumData[this.timeRowIds[time]];
  } else {
    this.timeRowIds[time] = this.cumData.length;
    newLine = {"time":time};
    this.cumData.push(newLine);
  }
  for (i=0;i<this.tgts.length;i++) {
    toZap = this.tgts[i];
    newLine[toZap] = JSON.stringify(latest[toZap])
  }
    h = notebookPaneHeight()-275;
  this.t = $('#' + this.port + "_table").dataTable({"data":this.cumData,
				       "columns":this.columns,
				       "destroy":true,
        "scrollY": h,
        "scrollCollapse": true,
        "paging": false,
        "jQueryUI": true});
//  this.t.api().page.jumpToData( time, 0 );
// above selects page with data, but we want to scroll to it
    var newRow = this.timeRowIds[time];
    var scroller = this.t.fnSettings().nTable.parentNode;
    var rowObj = this.t.api().row(newRow).node();
// console.log("outer: " + $(scroller).position().top + "' inner: " + $(rowObj).offset().top);
//    $(scroller).scrollTo(rowObj,{offsetTop:400,duration:1});
    $(scroller).animate({ scrollTop: $(rowObj).offset().top-$(scroller).offset().top-h/2})

// sorted -- next, make the bloody thing change size
}

DataTable.prototype.resize = function(x,y) {
    this.t.fnSettings().oScroll.sY = y-275;
    this.t.fnDraw();
}

function flatten(head,ob) {
    var result = {};
    if (typeof (ob) == "object") {
	for (var neck in ob) {
	    var iny = flatten(head, ob[neck]);
	    for (var item in iny) {
		result[neck + ',' + item] = iny[item];
	    }
	}
    } else {
	result[head] = ob;
    }
    return result;
}

function Shapes3D (port) {
  this.port = port;
    this.tgts = [];
    this.State = [];
    this.showing = {};
  this.status = "displaying";
//      w = 800;
      w = parseInt(d3.select('#tabs').style('width'), 10)-50;
//      h = 800;
      h = notebookPaneHeight()-120;

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera( 75, w/h, 0.1, 1000 );
    var renderer = new THREE.WebGLRenderer();
    renderer.setSize( w, h );

    $('#' + port).html("<div id='demo_drop2'></div>\
<div id='" + port + "_div'></div>");

    ShowMenuButton(this);
// demo dropdown 2 ---------------------------------------------------------

    document.getElementById(port + "_div").appendChild( renderer.domElement );

    // CONTROLS
    controls = new THREE.OrbitControls( camera, renderer.domElement );

	///////////
	// LIGHT //
	///////////
	
	// create a light
	var light = new THREE.PointLight(0xffffff);
	light.position.set(0,250,0);
	scene.add(light);
	var ambientLight = new THREE.AmbientLight(0x404040);
	scene.add(ambientLight);
	
	///////////
	// FLOOR //
	///////////
	
	// note: 4x4 checkboard pattern scaled so that each square is 25 by 25 pixels.
	var floorTexture = new THREE.ImageUtils.loadTexture( 'images/checkerboard.jpg' );
	floorTexture.wrapS = floorTexture.wrapT = THREE.RepeatWrapping; 
	floorTexture.repeat.set( 10, 10 );
	// DoubleSide: render texture on both sides of mesh
//    var floorMaterial = new THREE.MeshBasicMaterial( { map: floorTexture, side: THREE.DoubleSide, opacity: 0.75 } );
//	var floorGeometry = new THREE.PlaneGeometry(1000, 1000, 1, 1);
//	var floor = new THREE.Mesh(floorGeometry, floorMaterial);
//	floor.position.y = -0.5;
//	floor.rotation.x = Math.PI / 2;
//	scene.add(floor);

    // test some new shapes!

    var geometry = new THREE.CylinderGeometry( 5, 10, 50, 32 );
    var material = new THREE.MeshLambertMaterial( {color: 0xffff00, 
						transparent: true,
						opacity: 0.8} );
    var cylinder = new THREE.Mesh( geometry, material );
    cylinder.rotation.set(1,0,1);
//    scene.add( cylinder );
    
    var circleGeom = new THREE.CircleGeometry(500,24);
    var baseCirc = [{"col":0xff0000,"rot":[0,0]},
		    {"col":0x00ffff,"rot":[0,3.14]},
		    {"col":0x00ff00,"rot":[0,1.57]},
		    {"col":0xff00ff,"rot":[0,-1.57]},
		    {"col":0x0000ff,"rot":[-1.57,0]},
		    {"col":0xffff00,"rot":[1.57,0]}];
		    
    for (var i=0; i<baseCirc.length; ++i) {
	var circleMat = new THREE.MeshBasicMaterial( {map: floorTexture,
						      color : baseCirc[i].col, 
						      transparent: true,
						      opacity: 0.5});
	var circle = new THREE.Mesh(circleGeom, circleMat);
	circle.rotation.set(baseCirc[i].rot[0], baseCirc[i].rot[1], 0);
	scene.add(circle);
    }
    
    camera.position.set(0,150,400);
    camera.lookAt(scene.position);	

    var render = function () {
	requestAnimationFrame( render );
	// cube.rotation.x += 0.1; cube.rotation.y += 0.1;
	renderer.render(scene, camera);
	controls.update();
    };
    render();
    this.scene = scene;
    this.renderer = renderer;
}

function ShowMenuButton (that) {
    $('#demo_drop2').html("\
  <div id='launcher2_container'>\
    <button id='launcher2'>Select new item type</button>\
  </div>\
  <ul id='menu2'>\
    <li id='spheres'><a href='javascript:void(0);'>Sphere</a></li>\
    <li id='lines'><a href='javascript:void(0);'>Line</a></li>\
    <li id='lollipops'><a href='javascript:void(0);'>Lollipop</a></li>\
    <hr>\
    <li id='ellipses'><a href='javascript:void(0);'>Ellipse</a></li>\
  </ul>");
    
    $("#demo_drop2").jui_dropdown({
    launcher_id: 'launcher2',
    launcher_container_id: 'launcher2_container',
    menu_id: 'menu2',
    containerClass: 'container2',
      menuClass: 'menu2',
//    launcher_is_UI_button: false,
      onSelect: function(event, data) {
	  //      $("#result").text('index: ' + data.index + ' (id: ' + data.id + ')');
	  AddItem(that, data.id);
    }
  });
}

function AddItem (that, type) {
//    console.log('AI ' + JSON.stringify(that));
    // next make this look more like ZooXYZ.tcl
    var allTemplates = {"spheres":[["type","Select new item type"],
				  ["component","X positions"],
				  ["component","Y positions"],
				  ["component","Z positions"],
				  ["component","size values"],
				  ["colour","colour"]],
			"lines":[["type","Select new item type"],
				["component","start X positions"],
				["component","start Y positions"],
				["component","start Z positions"],
				["component","end X positions"],
				["component","end Y positions"],
				["component","end Z positions"],
				["component","width values"],
				["colour","colour"]],
			"lollipops":[["type","Select new item type"],
				  ["component","X positions"],
				  ["component","Y positions"],
				  ["component","size values"]],
			"ellipses":[["type","Select new item type"],
				   ["component","centre X positions"],
				   ["component","centre Y positions"],
				   ["component","centre Z positions"],
				   ["component","length of major radii"],
				   ["component","eccentricities"],
				   ["component","X rotations"],
				   ["component","Y rotations"],
				   ["component","Z rotations"],
				   ["colour","front"],
				   ["colour","back"]]};
    that.template = allTemplates[type];
    that.newComps = [];
    MakeSelection(that, type);
}

function MakeSelection (that, selected) {
//    console.log('MS ' + JSON.stringify(that));
    for (i=0;i<that.template.length;i++) {
	code = ["type","component","colour"].indexOf(that.template[i][0]);
	if (code>-1) {
	    if (code == 1) { // component, put in list
		that.newComps.push(selected);
	    }
	    that.template[i] = selected;
	    break;
	}
    }
    i++;
    if (i == that.template.length) { // finished
	that.template[i] = {}; // new empty display object list
	oldState = that.State;
	that.State = [that.template]; // New items only
	newData = {};
	for (j=0; j<that.newComps.length; ++j) {
	    nItm = that.newComps[j]
	    newData[nItm] = JSON.parse(values_json[nItm]);
	}
	that.display(parseFloat($("#ct").val()),newData,false),
	that.State = oldState;
	that.State.push(that.template);
	ShowMenuButton(that);
    } else {
	switch (that.template[i][0]) {
	case "component":
	    $('#demo_drop2').text('Click on component with ' + that.template[i][1] + ' of ' + that.template[0]);
	    break;
	case "colour":
	    $('#demo_drop2').text('Choose ' + that.template[i][1] + ' of ' + that.template[0] + ': '); // provide JSColor widget calling this back with colour
	    clr = document.createElement('INPUT')
	    // bind jscolor
	    var col = new jscolor.color(clr);
	    document.getElementById('demo_drop2').appendChild(clr);
	    
	    var btn = document.createElement('button');
	    btn.innerHTML = 'OK';
	    btn.onclick = function(){
		MakeSelection(that, col.toString()); // no
		return false;
	    };
	    document.getElementById('demo_drop2').appendChild(btn);
	    break;
	default:
	    console.log("Worng datum type: " + that.template[i][0]);
	}
    }   
}

Shapes3D.prototype.acceptClick = function (compId) {
    this.tgts.push(compId);
    MakeSelection(this, compId);
}

Shapes3D.prototype.display = function (time, latest, connect) {
    lolliCount = 0;
    lolliCols = [0x00ff00, 0xf1da7e, 0x36b694, 0xec9844, 0x94a646, 0xd9d095];
    // now add new ones
    for (j=0; j<this.State.length; ++j) {
	instruct = this.State[j];
	switch (instruct[0]) {
	case "spheres":
	    // first remove old items
	    for (var old in instruct[6]) {
		this.scene.remove(instruct[6][old]);
		delete(instruct[6][old]);
	    }
	    instruct[6] = {};

	    defns = {};
	    for (i=1;i<5;++i) {
		defns[["n","x","y","z","r"][i]] = flatten("s",latest[instruct[i]]);
	    }
	    nC = parseInt('0x' + instruct[5]);
	    var sphereMaterial = new THREE.MeshLambertMaterial( {color: nC} ); 
	    var sphereGeometry = new THREE.SphereGeometry(1.0, 32, 16 ); 
	    for (iV in defns.r) {
		if (defns.r[iV] < 1) continue;
		// Sphere parameters: radius, segments along width, segments along height
	// use a "lambert" material rather than "basic" for realistic lighting.
		    //   (don't forget to add (at least one) light!)
		    
		var sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
		sphere.position.set(defns.x[iV], defns.z[iV], defns.y[iV]);
		sphere.scale.set(defns.r[iV], defns.r[iV], defns.r[iV]);
		instruct[6][iV] = sphere;
		this.scene.add(sphere);
	    }
	    break;
	case "lines":
	    for (var old in instruct[9]) {
		this.scene.remove(instruct[9][old]);
		delete(instruct[9][old]);
	    }
	    instruct[9] = {};

	    defns = {};
	    for (i=1;i<8;++i) {
		defns[["n","sx","sy","sz","fx","fy","fz","w"][i]] = flatten("l",latest[instruct[i]]);
	    }
	    nC = parseInt('0x' + instruct[8]);
	    var lineGeometry = new THREE.CylinderGeometry(0.5,0.5,1.0);
	    var lineMaterial = new THREE.MeshLambertMaterial( {color: nC} );
	    for (iV in defns.w) {
		if (defns.w[iV] < 1) continue;

	/* Old version: used lineGeometry, which lacks width in Windows
		var lineMaterial = new THREE.LineBasicMaterial(
		    {color: nC,	linewidth: defns.w[iV]} ); 
		var lineGeometry = new THREE.Geometry();
		lineGeometry.vertices.push(
		    new THREE.Vector3(defns.sx[iV], defns.sz[iV], defns.sy[iV]),
		    new THREE.Vector3(defns.fx[iV], defns.fz[iV], defns.fy[iV])
		);
		var line = new THREE.Line(lineGeometry, lineMaterial);

	New version uses cylinders */
		var line = new THREE.Mesh(lineGeometry, lineMaterial);
		line.position.set((defns.fx[iV]+defns.sx[iV])/2,
				  (defns.fz[iV]+defns.sz[iV])/2,
				  (defns.fy[iV]+defns.sy[iV])/2);
		xyExt = Math.pow(defns.fx[iV]-defns.sx[iV],2)+
		    Math.pow(defns.fy[iV]-defns.sy[iV],2);
		line.scale.set(defns.w[iV], Math.sqrt(xyExt +
					 Math.pow(defns.fz[iV]-defns.sz[iV],2)),
			       defns.w[iV]);
		line.rotation.set(0,
				  -Math.atan2(defns.fy[iV]-defns.sy[iV],
					     defns.fx[iV]-defns.sx[iV]),
				  -Math.atan2(Math.sqrt(xyExt), defns.fz[iV]-defns.sz[iV]));
		instruct[9][iV] = line;
		this.scene.add(line);
	    }
	    break;
	case "lollipops":
	    // first remove old items
	    for (var old in instruct[4]) {
		this.scene.remove(instruct[4][old]);
		delete(instruct[4][old]);
	    }
	    instruct[4] = {};

	    defns = {};
	    for (i=1;i<4;++i) {
		defns[["n","x","y","h"][i]] = flatten("p",latest[instruct[i]]);
	    }
	    nC = lolliCols[lolliCount++];
	    var sphereMaterial = new THREE.MeshLambertMaterial( {color: nC} ); 
	    var sphereGeometry = new THREE.SphereGeometry(1.0, 32, 16 ); 
	    var lineMaterial = new THREE.MeshLambertMaterial({color: 0x084000});
	    var lineGeometry = new THREE.CylinderGeometry(0.5,0.5,1.0);
	    for (iV in defns.h) {
		if (defns.h[iV] < 1) continue;
		// Sphere parameters: radius, segments along width, segments along height
	// use a "lambert" material rather than "basic" for realistic lighting.
		    //   (don't forget to add (at least one) light!)
		    
		var sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
		sphere.position.set(defns.x[iV], 3*defns.h[iV]/2, defns.y[iV]);
		sphere.scale.set(defns.h[iV]/2, defns.h[iV]/2, defns.h[iV]/2);
		instruct[4][iV+"s"] = sphere;
		this.scene.add(sphere);

		var line = new THREE.Mesh(lineGeometry, lineMaterial);
		line.position.set(defns.x[iV], defns.h[iV]/2, defns.y[iV]);
		line.scale.set(2, defns.h[iV], 2);
		instruct[4][iV+"l"] = line;
		this.scene.add(line);
	    }
	    break;
	case "ellipses":
	    for (var old in instruct[11]) {
		this.scene.remove(instruct[11][old]);
		delete(instruct[11][old]);
	    }
	    instruct[11] = {};

	    defns = {};
	    for (i=1;i<9;++i) {
		defns[["n","cx","cy","cz","r","e","rx","ry","rz"][i]] =
		    flatten("l",latest[instruct[i]]);
	    }
	    fC = parseInt('0x' + instruct[9]);
	    bC = parseInt('0x' + instruct[10]);
	    var circleGeom = new THREE.CircleGeometry(1,24);
	    var circleMat = new THREE.MeshLambertMaterial( {color : fC});
	    var circleBack = new THREE.MeshLambertMaterial( {color : bC});
	    for (iV in defns.r) {
		if (defns.r[iV] < 1) continue;

		var circle = new THREE.Mesh(circleGeom, circleMat);
		circle.position.set(defns.cx[iV], defns.cz[iV], defns.cy[iV]);
		circle.scale.set(defns.r[iV], defns.r[iV]/defns.e[iV], 1);
		circle.rotation.set(-defns.rx[iV]-1.57, -defns.ry[iV],
				    -defns.rz[iV], 'XZY');
		instruct[11][iV + ",f"] = circle;
		this.scene.add(circle);

		circle = new THREE.Mesh(circleGeom, circleBack);
		circle.position.set(defns.cx[iV], defns.cz[iV], defns.cy[iV]);
		circle.scale.set(defns.r[iV], defns.r[iV]/defns.e[iV], 1);
		circle.rotation.set(-defns.rx[iV]+1.57, defns.ry[iV],
				    defns.rz[iV], 'XZY');
		instruct[11][iV + ",b"] = circle;
		this.scene.add(circle);
	    }
	    break;

	default:
	    alert("Unrecognized item type: " + instruct[0]);
	}
    }
}

Shapes3D.prototype.resize = function (x,y) {
    this.renderer.setSize(x-50, y-120);
}

function PlotXY (port) {
  this.port = port;
  this.tgts = [];
  this.yvals = [];
  this.oldys = [];
    this.nrun = 0;
  this.status = "initializing";

// OK now add the message to the new tab
  $('#' + port).html("Click on a component to plot on the Y axis.");
}

var xyGlbsForD3 = {};
PlotXY.prototype.acceptClick = function (compId) {
  if (this.status == "initializing") {
    this.tgts.push(compId);
    this.yvals.push(compId);
    addys = flatten('t', JSON.parse(values_json[compId]));
    buttonFn = "select_for_helper('time')";
    $('#' + this.port).html("Click on a component to plot on the X axis, or <button type='button' onclick=" + buttonFn + ">here</button> to plot against time.");
    this.status = "getting_x";
  } else if (compId == "add") {
      $('#' + this.port).find('#instruct')
	    .html("Click on a component to plot on the Y axis.");
      this.status = "adding";
  } else {
      ngap = 40;
//      w = 800;
      w = parseInt(d3.select('#' + this.port).style('width'), 10)-ngap;
      //      h = 800
      ;
      h = notebookPaneHeight()-120;

    if (compId == "clear") {
	delete this.ymin;
	delete this.ymax;
	delete this.xmin;
	delete this.xmax;
	grps = this.svg.selectAll(".step");
	grps.selectAll(".trace").remove();
	grps.remove();
	this.nrun = 0;
    } else if (compId == "time") {
	this.oldt = parseFloat($("#ct").val());
	this.xval = 'time';
	xAxisName = 'time';
    } else if (this.status == "adding") {
	$('#' + this.port).find('#instruct').html(''); // delete message
	this.tgts.push(compId);
	this.yvals.push(compId);
	addys = flatten('t', JSON.parse(values_json[compId]));
    } else {
	this.tgts.push(compId);
	this.xval = compId;
	this.oldxs = flatten('t', JSON.parse(values_json[compId]));
	xAxisName = model_json[compId].captpath;
    }
      
      if (this.xval == 'time' && this.status != "adding") { 
// initialize bounds, x axis is time
	this.xmin = this.oldt;
	this.xmax = this.oldt + parseFloat($("#rl").val());
      }
      for (var hdl in addys) {
	if (this.xval != 'time') {
	    if (this.xmin == undefined || this.oldxs[hdl] < this.xmin) {
		this.xmin = this.oldxs[hdl];
            }
	    if (this.xmax == undefined || this.oldxs[hdl] > this.xmax) {
		this.xmax = this.oldxs[hdl];
	    }
	}
	if (this.ymin == undefined || addys[hdl] < this.ymin) {
	    this.ymin = addys[hdl];
        }
	if (this.ymax == undefined || addys[hdl] > this.ymax) {
	    this.ymax = addys[hdl];
	}
    }
// rest is initialization so if only clearing, we are done
    if (compId == "clear") {
	this.lx.domain([this.xmin,this.xmax]);
	this.ly.domain([this.ymax,this.ymin]);
	return
    } else if (this.xval == 'time') { // x axis is time
// oldys must become an array as maybe more than one var...
	this.oldys.push(addys);
	if (this.status == "adding") {
	    this.status = "displaying";
// adjust y axis for range of new addition, then we are done
	    this.ly.domain([this.ymax,this.ymin]);
	    return;
	}
    } else {
	this.oldys = addys;
    }
      this.status = "displaying";
    var x = d3.scale.linear()
	  .domain([this.xmin,this.xmax])
	  .range([ngap, w+ngap]);
    var y = d3.scale.linear()
	  .domain([this.ymax,this.ymin])
	  .range([0, h]);
    var xAxis = d3.svg.axis()
	  .scale(x)
	  .tickSize(-h)
	  .orient("bottom");
    var yAxis = d3.svg.axis()
	  .scale(y)
	  .tickSize(-w)
	  .orient("left");

    var gLine = d3.svg.line()
	  .y(function(d) {
	      return y(d.y);
	  })
	  .x(function(d) {
	      return x(d.x);
	  });
      this.lx = x;
      this.ly = y;
      this.lxAxis = xAxis;
      this.lyAxis = yAxis;
      this.line = gLine;
    buttonFn = "select_for_helper('clear')";
    $('#' + this.port).html("<div id='Buttonbar'><button onclick=" + buttonFn
			    + "><img src='images/new.gif'/></button></div>");
    if (compId == "time") {
	buttonFn = "select_for_helper('add')";
	$('#' + this.port).find('#Buttonbar')
	    .append("<button onclick=" + buttonFn
		    + "><img src='images/add.gif'/></button><div id='instruct'></div>");
    }
    $('#tabs a[href=#' + this.port + ']').text("Plot of " + model_json[this.tgts[0]].captpath + " against " + xAxisName);
    this.svg = d3.select('#' + this.port).append("svg")
      .attr("width",w+ngap).attr("height",h+ngap);
    var xAxisGroup = this.svg.append("g")
          .attr("id", this.port + "_xbar")
	  .attr("class", "x axis")
	  .attr("transform", "translate(0," + h + ")");
    var yAxisGroup = this.svg.append("g")
          .attr("id", this.port + "_ybar")
	  .attr("class", "y axis")
	  .attr("transform", "translate(" + ngap + ",0)");
      var portStr = this.port;
      var zoomFn = function() {redraw.call(this, portStr,yAxis,xAxis, gLine) };
      var zoomendFn = function() {resetAxes.call(this, zoomxaxis, zoomyaxis,
						 zoomport, x, y) };
      this.zfn = zoomFn;
      this.zefn = zoomendFn;
      var zoomxaxis = d3.behavior.zoom()
	  .x(x)
	  .on("zoom", zoomFn)
          .on("zoomend", zoomendFn);
      var zoomyaxis = d3.behavior.zoom()
          .y(y)
	  .on("zoom", zoomFn)
          .on("zoomend", zoomendFn);
      var zoomport = d3.behavior.zoom()
	  .x(x)
          .y(y)
	  .on("zoom", zoomFn)
          .on("zoomend", zoomendFn);
      this.svg.append("rect") // x scale
	  .attr("class", "pane")
	  .attr("y",h)
	  .attr("width", w+ngap)
	  .attr("height", ngap)
	  .call(zoomxaxis);
      this.svg.append("rect") // y scale
	  .attr("class", "pane")
	  .attr("width", ngap)
	  .attr("height", h)
	  .call(zoomyaxis);
      this.svg.append("rect") // port
	  .attr("class", "pane")
          .attr("x", ngap)
	  .attr("width", w)
	  .attr("height", h)
	  .call(zoomport);
      redraw(portStr,yAxis,xAxis);

  }
}
  
function redraw (port,yAxis,xAxis,line) {
    d3.select('#' + port + "_ybar").call(yAxis);
    d3.select('#' + port + "_xbar").call(xAxis);
    d3.select('#' + port)
	.selectAll(".step")
	.selectAll(".trace")
	.attr("d", line);
}

function resetAxes (zoomxaxis, zoomyaxis, zoomport, x, y) {
// now reset zoom axes so next one is always relative
    zoomxaxis.x(x);
    zoomyaxis.y(y);
    zoomport.x(x).y(y);
}

PlotXY.prototype.resize = function(x,y) {
   if (this.status != "displaying") return;
//   console.log('Tab width: ' + d3.select('#' + this.port).style('width'));
//   console.log('Notebook height: ' + d3.select('#tabs').style('height'));
    ngap = 40;
//      w = 800;
      w = x-ngap;
//      h = 800;
      h = y-120;
    this.lx.range([ngap, w+ngap]);
    this.ly.range([0, h]);
    this.lxAxis.tickSize(-h);
    this.lyAxis.tickSize(-w);
    d3.select('#' + this.port + "_xbar")
	.attr("transform", "translate(0," + h + ")");
    this.svg.attr("width",w+ngap).attr("height",h+ngap);
    this.zfn();
}

PlotXY.prototype.display = function (time, latest, connect) {
  if (this.status == "displaying") {
// OK now how big is it? 
      idxs = [[]];
// console.log(" data is " + JSON.stringify(latest[this.tgts[0]]) + " flat " + JSON.stringify(newys));
      if (this.xval != 'time') {
	  newys = flatten('t', latest[this.yvals[0]]);
	  newxs = flatten('t', latest[this.xval]);
	  for (var hdl in newys) {
	      if (connect && this.oldys[hdl] != undefined) {
		  idxs[0].push([{"y":this.oldys[hdl],"x":this.oldxs[hdl]},
			     {"y":newys[hdl],"x":newxs[hdl]}]);
	      }
	      if (this.ymin == undefined) {
		  this.ymin = this.ymax = newys[hdl];
		  this.xmin = this.xmax = newxs[hdl];
	      } else {
		  this.ymin = Math.min(this.ymin,newys[hdl]);
		  this.ymax = Math.max(this.ymax,newys[hdl]);
		  this.xmin = Math.min(this.xmin,newxs[hdl]);
		  this.xmax = Math.max(this.xmax,newxs[hdl]);
	      }
	  }
	  this.oldys = newys;
	  this.oldxs = newxs;
      } else {
	  for (var i=0; i<this.yvals.length; ++i) {
	      idxs[i] = [];
	      newys = flatten('t', latest[this.yvals[i]]);
	      for (var hdl in newys) {
		  if (connect && this.oldys[i][hdl] != undefined) {
		  idxs[i].push([{"y":this.oldys[i][hdl],"x":this.oldt},
			     {"y":newys[hdl],"x":time}]);
		  }
		  oldymin = this.ymin;
		  if (this.ymin == undefined) {
		      this.ymin = this.ymax = newys[hdl];
		  } else {
		      this.ymin = Math.min(this.ymin,newys[hdl]);
		      this.ymax = Math.max(this.ymax,newys[hdl]);
		  }
// console.log("ymin was " + oldymin + " checked " + newys[hdl] + " is " + this.ymin);
	      }
	      this.oldys[i] = newys;
	  }
	  this.oldt = parseFloat(time);
	  if (this.oldt<this.xmin) {
	      this.xmin = this.oldt;
	  }
	  if (this.oldt>this.xmax) {
	      this.xmax = parseFloat($("#ct").val()) + parseFloat($("#rl").val());
//	      console.log("Boring x range out to " + this.xmax);
// now I need to redraw
	  }
      }
      if (connect) {
	  for (i=0; i<idxs.length; ++i) {
	  var col = "blue orange green brown purple red black DeepSkyBlue HotPink ForestGreen".split(" ")[this.nrun+i];
	  newGrp = this.svg.append("g")
              .attr("class", "step"); // new group for this time step's data
	  newGrp.selectAll(".line") // selects empty set?
	      .data(idxs[i])
	      .enter().append("path")
	      .attr("class", "trace")
	      .style("stroke",col)
	      .attr("d", this.line);
	  }
      } else {
	  this.nrun += this.yvals.length;
      }

      squeezed = 0;
      XMinMax = this.lx.domain();
      if (!(this.xmin >= XMinMax[0])) {
	  squeezed = 1;
	  XMinMax[0] = this.xmin;
      }
      if (!(this.xmax <= XMinMax[1])) {
	  squeezed = 1;
	  XMinMax[1] = this.xmax;
      }
      YMinMax = this.ly.domain();
      if (!(this.ymin >= YMinMax[1])) {
	  squeezed = 1;
	  YMinMax[1] = this.ymin;
      }
      if (!(this.ymax <= YMinMax[0])) {
	  squeezed = 1;
	  YMinMax[0] = this.ymax;
      }

      if (squeezed) {
	  this.lx.domain(XMinMax);
	  this.ly.domain(YMinMax);
	  this.zfn();
	  this.zefn();
      }
//      bbox = newGrp.node().getBBox();
//      console.log("Current bbox x,y,w,h = " + bbox.x + ", " + bbox.y + ", " +
//		  bbox.width + ", " + bbox.height);
  }
}

PlotXY.prototype.olddisplay = function (time, latest) {
  if (this.status == "displaying") {
      newys = flatten('t', latest[this.tgts[0]]);
      if (this.tgts[1] != undefined) {
	  newxs = flatten('t', latest[this.tgts[1]]);
      }
      for (var hdl in newys) {
//	  alert("Adding line from " + this.oldxs[hdl] + ", " + this.oldys[hdl]
//		+ " to " + newxs[hdl] + ", " + newys[hdl]);
	  nlin = document.createElementNS (xmlns, "line");
	  this.g.appendChild (nlin);
	  nlin.setAttribute('y1', -this.oldys[hdl]);
	  nlin.setAttribute('y2', -newys[hdl]);
	  if (this.tgts[1] == undefined) {
	      nlin.setAttribute('x1', this.oldt);
	      nlin.setAttribute('x2', time);
	  } else {
	      nlin.setAttribute('x1', this.oldxs[hdl]);
	      nlin.setAttribute('x2', newxs[hdl]);
	      if (newxs[hdl] < this.xmin) {
		  this.xmin = newxs[hdl];
              }
	      if (newxs[hdl] > this.xmax) {
		  this.xmax = newxs[hdl];
	      }
	  }
	  if (newys[hdl] < this.ymin) {
	      this.ymin = newys[hdl];
          }
	  if (newys[hdl] > this.ymax) {
	      this.ymax = newys[hdl];
	  }
          nlin.style.stroke = "black";
          nlin.style.vectorEffect = "non-scaling-stroke";
      }
      this.oldys = newys;
      if (this.tgts[1] == undefined) {
	  this.oldt = time;
	  if (time>this.xmax) {
	      this.xmax = parseFloat($("#ct").val()) + parseFloat($("#rl").val());
	  }
      } else {
	  this.oldxs = newxs;
      }
      vbStr = this.xmin + " " + (-this.ymax) + " "
	  + (this.xmax-this.xmin) + " " + (this.ymax-this.ymin);
//      alert(vbStr);
      this.g.setAttributeNS(null, "viewBox", vbStr);
      this.g.setAttributeNS(null, "preserveAspectRatio", "none");
  }
}

function AlterRange(that, factor) {
    that.tgts[0].bottom = that.tgts[0].bottom * factor;
    that.tgts[0].top = that.tgts[0].top * factor;
}

function Grid5 (port) {
    this.port = port;
    this.tgts = [];
    this.status = "initializing";

    bar = d3.select('#' + port).append("div").attr("id", port + "_Buttonbar");
    bar.append("button").html("<img src='images/less.gif'/>")
	.style('float','left').on('click', function() {AlterRange(that, 0.5) });
    bar.append("button").html("<img src='images/greater.gif'/>")
	.style('float','left').on('click', function() {AlterRange(that, 2.0) });
    bar.append("div").attr("id", port + "_instruct").style('float','left');
    
    this.scaleGrp = d3.select('#' + port).append("svg")
	.attr("width",800).attr("height",480).attr("id", port + "_diag")
	.append("g");
    diag_zoom = d3.behavior.zoom()
	.on("zoom", function () {
	    d3.select('#' + port + '_diag').select('g')
		.attr("transform", "translate(" + d3.event.translate +
		      ")scale(" + d3.event.scale + ")");
	});
    d3.select('#' + port + '_diag').attr("class","pane").call(diag_zoom);
    d3.select('#' + port + '_instruct').html("Select component with values to display in grid");
    this.scaleGrp.append("svg:image")
	.attr("id", port + "_img")
	.attr("width","49px")
	.attr("height","49px")
	.style("imageRendering","pixelated")
	.attr("xlink:href", "data:image/bmp;base64,Qk2MHAAAAAAAADYAAAAoAAAAMQAAADEAAAABABgAAAAAAFYcAAASCwAAEgsAAAAAAAAAAAAA////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7+/v39/fv7+/v7+/v7+/z8/P39/f7+/v///////////////////////////////////////wD////////////////////////////////////////////+/v78/Pz7+/v7+/v8/Pz+/v7////////////////////////////////////////////+/v78/Pz4+Pj19fXx8fHu7u7t7e3t7e3v7+/y8vL19fX5+fn8/Pz+/v7///////////////////////////8A/////////////////////////////////v7++/v79/f39PT08PDw7e3t7e3t8PDw9PT09/f3+/v7/v7+/////////////////////////////Pz89/f37+/v6Ojo4+Pj4ODg39/f3t7e3t7e39/f4eHh5OTk6urq8fHx+Pj4/f39////////////////////////AP////////////////////////////z8/Pf39+7u7ufn5+Li4uDg4N7e3t7e3uDg4OLi4ufn5+3t7fT09Pr6+v7+/v////////////7+/vr6+vHx8efn5+Dg4Nzc3M67tMiroMKcjcKcjsuzrM27ttnZ2dra2t3d3eHh4enp6fPz8/v7+////////////////////wD////////////////////////7+/vy8vLn5+fg4ODZ0cPVxanRsXrRsXrVxanZ0sTZ2dnb29vf39/k5OTt7e339/f9/f3////+/v75+fnu7u7j4+PKraK6hnGsYEGsYEGsYEOsYEesYEyrYFCrYFSuaGC8jovNu7va2trd3d3l5eXx8fH7+/v///////////////8A////////////////////+/v78fHx5OTk1r6UzplCzY0g1pok26Ep3KMs26Au2Z4w16dR172R2dXP29vb39/f6Ojo8vLy+vr6+fn57u7u18nDtXderGBCrmNFrWNGq2BGq2BKq2BQq2BVq2BZq2BcqmFgqmFjqmFntn+G08rM3Nzc5OTk8fHx/Pz8////////////AP////////////////z8/PLy8uDUv9CdQsyMJNecJ9+nKt2kK9yiLdqgL9mdMNebMtWZM9OXNNKYPtW5kdra2t3d3eTk5Ozs7O3t7c6ypbdxSb16T716T7t3T7l0T7lzT7l0T7l1Url2Xb17Xrt6Ybh2ZLJtbqtidahgdaxpetDCx9zc3OXl5fT09P39/f///////wD////////////+/v739/fj18LRlyzOjyjZnirfpirdoyvboS3any/YnTHWmjLUmDTTljTRlDTQkTbOjzjPoGLXz8bb29ve3t7Tuae8d0nAfU3AfU/BgE7Ji0nYpV/kwJHt17/16eDy49HOlVfQllLNklDLj07Gh0+5dWCnW36oYoXQwsfd3d3q6ur5+fn///////8A////////////+/v76d7I1Jou0ZQm1psu3qUq3KMs26Eu2Z4w2Jwx1poz1Jg00pY00ZM0z5E3zo85zIw6yoo90ZdE38yW0sS8uXJDu3VGv3xG1Jg56MBn9OPB////////////////////8ODTxolUyI1ZxYlXw4RVv39SvXxRq2Fvo1eL19LU4+Pj8/Pz/f39////AP////////////f399ioSdWZJNmjR+rAbPHUnvXguvLUoejAe96pUtWaONKVNNGSNc+QN82OOcuMO8mJPsiHQMaFQ8yNPtSbNatdN8B7MeO6Uu/ivfr6+v7+/v///////////////////////9atlMKFXcGCXb5+Wrt5V7h0VbdzValcb7SAp97e3u3t7fv7+////wD////////+/v7p1KjZoC/ovWvYtIDp5uL4+Pj////////////57t3owYjVm0TOkDjNjjrLizzJiT7HhkHGhEPDgUW6dD62bzPYni3TtHnc3Nzj4+Pu7u74+Pj+/v7////////////////////27uq6eFy7fGC4d161cVuxbFmvalmuaFmeTIDVy9Ho6Oj4+Pj///8A/////////f394LNZ7MR1vHYmwZp44+Pj9PT0/v7+////////////////8dq416BUyos8yIg/x4ZCxYNEwn9Fv3tIuXM9v3tBvHdM0ptM2s+929vb4eHh6+vr9vb2/f39////////////////////wYh7tXVjsm9grmldqmNaqGBap19bo1ZpvZe55eXl9/f3////AP////////ny4+q/ZsaDKbtyFb6LXd7e3uvr6/j4+P7+/v////////////////ThyNikY8eFQsWDRMJ+Rr97Sr56Rb97QrdxULRsU7JpVcqPVdjCpNra2t/f3+jo6PPz8/v7+/7+/v///////////8qcmLBuZa1oYqliYKRbXaNYXKJXXaFVXalon+Pj4/b29v///wD////////05snluGPGgBbHgx3BgTfa2trh4eHt7e339/f8/Pz////////////////37uHUn2LBfUe+ekrAfEa7dj+yaUyza1OxaFWvZFesYFi5c1fTspDa2trd3d3l5eXw8PD5+fn9/f3////////QqqqrZ2enYWSjWmGfU16cT12bTV2bTF6gVYTk5OT29vb///8A////////+vHd47NT0ZAb0JAgzY4tz7CP2tra4ODg6Ojo8fHx9vb2+Pj4+Pj49vb28vLy593QzpdgwX1Dt3A7rWI/s2pUsWdWrmNXq19ZqVxZp1hbrmNcypp82NTR29vb4eHh6+vr9fX1+/v7/v7+y6aopV9moVljnVJgmEpdlkdclUZdlERelT5z5+fn+Pj4////AP////////315Om6VdqdHticItidLNKZRtbCqtra2tzc3OHh4eTk5Ofn5+fn5+Xl5eHh4djMv8WQXcSESK9lN61hS65iVqxfWKpdWqhaWqZWW6RTXaFPXqZXX7x8adLBvNra2t7e3ubm5u/v7/X19b+UmZ9XZZtRYpZKX5JBW5A/W5A9XJA8XJpHgevr6/r6+v///wD////////+/Pjtw1/hqCDfpiPepivgqz3erVfcvJDb08jZ2dna2trb29vb29vZ0sfSq3rAfTasYCauYzG7dkaqXFeoWVmnV1qlVFujUlyhT12gS16eSV+eSWGeSWSuY2bGoZzX0tLb29vg4ODl5eWjZHGZT2KVSF+RQVyNOlmMOlmMOlmRPG2oZI3w8PD8/Pz///8A////////////996l6bUp5rAk5K4p5LE55bVN57pf575z58SK5smY4sOT265t051Tx4tDunUtsGYmqFs037+isWZcpVRgo1JgoU9hoExhnklinUhinUdjnUdlnEhonEZook9otHZ/zr3B2tra0cfJkERXk0lekENaiz1XiThViThVjDpglj6At4KV9vb2/v7+////AP////////////314/HIWuy6Jem1J+e0Mua2ROa4VOe7ZOi/b+i/deK2b9yrZtOcV8iLRLx4L7RvNOzd1P///+vTvqpdYqFOaJ9MZ55JZ51IZ51HZ5xGaJxGaZtGaptEappEappEaqNTcbV+k6VqgZBHWY5EWIo/VIY4UYU3UI07aJY+gJI0WdK0wfv7+////////wD////////////////558Dxxk3suibptivntTnmtkjmuFfmumLlumjgsWLaplvSmlLJjEO7eTbt39P////////////XrpSiUm6fTHCeSm6dSW2cSG2cR22bRWyaRGyZQ2uZQmuZQWyXPWmXPGibRWucS3eYSHmVQn6SPXuUPHeUOGeSM1SdTHD4+Pj+/v7///////8A////////////////////+OO48MZS67ko6LYw5rU85rZL5bdX5LZd365X2aRQ0plK27F/+vby////////////////////xJSwoVKAoE97nkx3nUl0nEdym0VwmkNvmUJumEFtmD9tljtpkzVdkjRWkjRUkjNTkTRTkTNRkTNRkjNUkjVe2LrK/v7+////////////AP////////////////////////vw2/LSh+y/T+i5ROa1QeW2TuS2WOGxWuXAgvTm0f///////////////////////////////8aXuqJViqBRgp5MfJxJeJtGdZpEc5lCcphAcZc+bpU6ZZQ3XZI0WJIzV5IzVpE0VpE0VpI0WJI1YLl/oP7+/v///////////////wD////////////////////////////////9+PD78eD68N/679778+b////////////////////////////////////////////////NpMWjV5GgUYieTIGcSHybRXiZQnSYQG+XPmuWPWiVOmSTNl6SM1qRM1mSM1qSNV6TNWa6gKL+/v7///////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////483hsHCnoVSPn06FnUp/m0Z5mUN1mEFxlz9vlz5slTlnkzdjkjRgkjVkkzZtyJq2////////////////////////////AP////////////////////////////////////////////////////////////////////////////////////////////////////////////r1+dKv0K9upaFTkJ5Nh5xJgZtGfJpDeZhBdpc+dJU7cZQ4cruCp/Hm7f///////////////////////////////wD////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////izOHQqsq3fKy2eKe0daSzdKO/irLRqsfy5+////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8A////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////");
}

Grid5.prototype.resize = function (x, y) {
   if (this.status != "displaying") return;
//   console.log('Tab width: ' + d3.select('#' + this.port).style('width'));
//   console.log('Notebook height: ' + d3.select('#tabs').style('height'));
    ngap = 40;
//      w = 800;
      w = x-ngap;
//      h = 800;
      h = y-ngap;
    d3.select('#' + this.port + '_diag').attr("width",w).attr("height",h);
}

Grid5.prototype.acceptClick = function (nodeId) {
    if (this.status == "initializing") {
	this.tgts[0] = {"format":"binary","node":nodeId,"bottom":0,"top":100};
	dims = model_json[nodeId].dims;

	if (dims.length == 3 && dims[0].isInteger && dims[1].isInteger) {
	    height = this.dims[0];
	    width = this.dims[1];
	} else {
	    d3.select('#' + this.port + '_instruct').html("Select component with values corresponding to grid columns");
	    this.status = "setting_aspect";
	    return;
	}
    } else if (this.status == "setting_aspect") {
	// now we need to get the unique value count and the grid data, and
	// draw once we have both...later...also how ro get n of values?
	width = 100;
	height = 100;
    }
    
    this.status = "displaying";
    d3.select('#' + this.port + '_instruct').html("");
    that = this; // no chance..
    // new version, tries to do GIF
    $.post('model_action.php', {"base":fileBase, "act":"Query",
				"note":JSON.stringify(this.tgts[0])},
	   function(gifTail) {
	       arr = JSON.parse(gifTail);
	       d3.select('#' + that.port + '_img')
		   .attr("width",width).attr("height",height)
		   .attr("xlink:href", that.headerGIF + arr);
	   });

    // GIF header
    data = 'GIF89a';
    data += conv16(width);                  // image width
    data += conv16(height);                  // image height

    data += String.fromCharCode(0xf7, 0, 0);
    // colour table, background colour, pixel aspect ratio

    //black -> red -> white
    for (var i=0; i<256; i+=2) {
	data += String.fromCharCode(i, 0, 0);
    }
    for (var i=1; i<256; i+=2) {
	data += String.fromCharCode(255, i, i);
    }

    data += String.fromCharCode(0x2c); // image descriptor
    data += conv16(0);                  // NW corner position of image
    data += conv16(0);                  // in logical screen
    data += conv16(width);                  // image width
    data += conv16(height);                  // image height

    // OK, how many bytes is that so far? 790? so include no-local-colour-table
    // and lzw-minimum-code-size bits to bring up to base64 char boundary
    data += String.fromCharCode(0, 8);
    this.headerGIF = 'data:image/gif;base64,' + btoa(data);
    resize_notebook();
}

function conv(size) {
    return String.fromCharCode(size&0xff, (size>>8)&0xff, (size>>16)&0xff, (size>>24)&0xff);
}
 
function conv16(size) {
    return String.fromCharCode(size&0xff, (size>>8)&0xff);
}
 
Grid5.prototype.display = function (time, latest, connect) {
    
    arr = latest[JSON.stringify(this.tgts[0])];
    d3.select('#' + this.port + '_img')
	.attr("width",width).attr("height",height)
	.attr("xlink:href", this.headerGIF + arr);
}

Grid5.prototype.displayBMP = function (time, latest, connect) {
    // For now, just shove some randum data in it

    arr = latest[JSON.stringify(this.tgts[0])];
    height = this.dims[0];
    width = this.dims[1];
    depth = 8;
    dataLen = width*height*depth/8;
    hdr = depth <= 8 ? 54 + Math.pow(2, depth)*4 : 54;
    // make a multiple of 3 so base64 data can be bolted on
    offset = 3*Math.ceil(hdr/3);

   //BMP Header
  data  = 'BM';                          // ID field
  data += conv(offset + dataLen);     // BMP size
  data += conv(0);                       // unused
  data += conv(offset);                  // pixel data offset
  
  //DIB Header
  data += conv(40);                      // DIB header length
  data += conv(width);                  // image width
  data += conv(height);                  // image height
  data += String.fromCharCode(1, 0);     // colour panes
  data += String.fromCharCode(depth, 0); // bits per pixel
  data += conv(0);                       // compression method
  data += conv(dataLen);              // size of the raw data
  data += conv(2835);                    // horizontal print resolution
  data += conv(2835);                    // vertical print resolution
  data += conv(0);                       // colour palette, 0 == 2^n
  data += conv(0);                       // important colours
  //Grayscale tables for bit depths <= 8
  if (depth <= 8) {
    data += conv(0);
    
    for (var s = Math.floor(255/(Math.pow(2, depth)-1)), i = s; i < 256; i += s)  {
      data += conv(i + i*256 + i*65536);
    }
  }
    // fill to 3*n
    while(data.length<offset) {
	data += ' ';
    }
  
    d3.select('#' + this.port + '_img')
	.attr("width",height).attr("height",height)
	.attr("xlink:href", 'data:image/bmp;base64,' + btoa(data) + arr);
}

/*
// eventually this will inherit from a generic display tool class
function PlotValAgainstTime (port) {
// Call the parent constructor
//   DisplayTool.call(this);

  this.port = port;
  this.tgts = [];
  this.status = "initializing";
// OK now add the message to the new tab
  $('#' + port).html("Click on a component in the Explorer pane or the Model Diagram.");
}

// PlotValueAgainstTime.prototype = new DisplayTool(this);
// PlotValueAgainstTime.prototype.constructor = new PlotValueAgainstTime;
PlotValAgainstTime.prototype.acceptClick = function (compId) {
  if (this.status == "initializing") {
    this.status = "displaying";
    this.tgts[0] = compId;
    plotId = this.port + "_plot";
    this.graphData = jQuery.extend(true,{},pgplot_data);
    origPt = {"x":$("#ct").val(),"y":parseFloat(values_json[compId])};
    this.graphData.main[0].data.push(origPt);
    $('#' + this.port).html("<figure style='height: 800px;' id='" + plotId + "'></figure>");
    this.myChart = new xChart('line', this.graphData, '#' + plotId, pgplot_opts); 
  }
}

PlotValAgainstTime.prototype.display = function (time, latest) {
  if (this.status == "displaying") {
    newPt = {"x":time.toString(),"y":parseFloat(latest[this.tgts[0]])};
//alert("Plotting: " + JSON.stringify(newPt));
    this.graphData.main[0].data.push(newPt);
    this.myChart.setData(this.graphData);
  }
}
*/
function populateStructs() {

// OK, now use AJAX to get a string of values

$.post('model_action.php', { "base":fileBase, "act":"Describe"}, 
      function(data) {

	  try {
	      model_json = JSON.parse(data);
	  } catch(err) {
	      console.log("Failed to parse: " + data);
	  }
// If there are file parameters, add a page to the tabbed notebook to display
// them (make this a function as user may kill and re-create)
// remove hook from tcl core when this is working
	   treeData = [];
	   fvParms = [];
	   needInput = 0;
	   for (var id in model_json) {
	      treeLine = model_json[id];
	      treeLine.id = id;
	      treeData.push(treeLine);

	      if (model_json[id].eval == "INPUT" || 
		  model_json[id].eval == "TABLE") {
		   fvParms.push(id);
		  if (model_json[id].eval == "TABLE") {
		      needInput = 1;
		  }
	      }
	   }
	   $('#explorer')
	   // listen for event
	      .on('changed.jstree', function (e, data) {
		   // $('#' + currentHelper).html('Node: ' + data.node.id);
		   select_for_helper( data.node.id );
	      })
	   // create the instance
	      .jstree({ 'core' : {
		   'data' : treeData
	      }
		      });
// This will ultimately load the parameter file (if there is one) and
// get a list of components that still need values, or have bad values,
// for flagging in the parameter dialogue
	  $.post('model_action.php', {"act":"LoadSPF", "base" : fileBase}, 
		 function(unfilled) {
console.log("Params needed: " + needInput + ", missing: " + unfilled);
		     if (needInput && JSON.parse(unfilled).length) {
			 new_helper("params");
		     }
		     model_reset();
		 });
      });

}

function loadParams() {
  parmBlock = {};
  for (i=0;i<fvParms.length;i++) {
    id = fvParms[i];
    input = "#prm_" + id;
    parmBlock[model_json[id].captpath] = $(input).val();
  }

  sendValues(parmBlock);
}

function sendValues(parmBlock) {
//alert(JSON.stringify(parmBlock));
  $.ajax({
    type: "POST",
    url: "model_action.php",
      data: { "base":fileBase, "act":"Parameterize", 
	      "data" : JSON.stringify(parmBlock)}
    })
      .done(function(retsStr) {
	  rets = JSON.parse(retsStr);
          if (rets != '') {
	    alert(rets);
          } else {
	    resetDepth = -1;
          }
// enable model execution if not already (if all vals OK)
    });
//    resetDepth = -1;
// needed because setting in callback fn above seems oddly to be out of scope
}

// window.onbeforeunload = function(e) {
//   return 'Warning: model state will be lost if you leave the site!';
// };
window.onunload = function(e) {
    $.post('model_action.php', { "act":"Exit", "base":fileBase});
};
// Version using UNIX sockets -- add .uxs extension to model name base
$.post('model_action.php', {"act":"CreateSocket", "base":fileBase},
       function(spew) {
	   console.log("Socket created: " + spew);
//           populateStructs();
       });

// Version using INET sockets -- ungainly and insecure
// Start the socket -- fttb just hope it is ready when prepare is called
//var svrPort = 99999;
//$.post('model_action.php', {"act":"CreateSocket", "base":fileBase},
//            function(port) {
////               alert("Guess what -- the model exec process just finished");
//            	svrPort = port;
//                console.log("Got socket " + port);
//            	populateStructs();
//});
//
$.post('model_action.php', {"act":"WaitSocket", "base":fileBase}, 
            function(port) {
//            	svrPort = port;
                console.log("Got socket " + port);
            	populateStructs();
});

////////////////////////////////////// PREPARE /////////////////////////////
var xmlns = 'http://www.w3.org/2000/svg';
var tooltip_grp;
var tooltip_bd;
var tooltip_qbg;
var tooltip_vbg;
var tooltip_q;
var tooltip_v;
var ModDiag;
var model_json;
var values_json;
var fvParms;
var timeUnit = "unit";
var diag_zoom;
function prepare() {
$.ajax({
  type: "POST",
  url: "model_action.php",
  data: {"act" : "GetSVG",  "base" : fileBase}
})
  .done (function(diagSVG) {
      document.getElementById("holds_svg").innerHTML = diagSVG;
  
      ModDiag = document.getElementById("mod_diag");
      diag_zoom = d3.behavior.zoom()
	  .on("zoom", function () {
	       d3.select('#mod_diag').select('g')
		  .attr("transform", "translate(" + d3.event.translate +
			")scale(" + d3.event.scale + ")");
	  });
      d3.select('#mod_diag').attr("class","pane").call(diag_zoom);
      resize_notebook();
    all = ModDiag.getElementsByTagName("*");
    for(var i = 0; i < all.length; i++) {
      var element = all[i];
      str = element.getAttribute("id");
      if (str != null) {
        var res = str.match(/\/background\//);
        if (res == null)		   
          addHoverAction(element);
      }
    }
    ModDiag.appendChild(tooltip_grp);
  });  
  // Create a path in SVG's namespace
  tooltip_grp = document.createElementNS(xmlns,'g');
  tooltip_bd = document.createElementNS(xmlns,'rect');
  tooltip_bd.setAttribute("x", "12");
  tooltip_bd.setAttribute("y", "12");
  tooltip_bd.setAttribute("width", "24");
  tooltip_bd.setAttribute("height", "24");
  tooltip_bd.setAttribute("visibility", "hidden");
  tooltip_bd.style.fill="none";
  tooltip_bd.style.stroke="black";
  tooltip_grp.appendChild(tooltip_bd);
  
  tooltip_qbg = document.createElementNS(xmlns,'rect');
  tooltip_qbg.setAttribute("x", "12");
  tooltip_qbg.setAttribute("y", "12");
  tooltip_qbg.setAttribute("width", "24");
  tooltip_qbg.setAttribute("height", "12");
  tooltip_qbg.setAttribute("visibility", "hidden");
  tooltip_qbg.style.fill="#e0ffe0";
  tooltip_qbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_qbg);
  
  tooltip_vbg = document.createElementNS(xmlns,'rect');
  tooltip_vbg.setAttribute("x", "12");
  tooltip_vbg.setAttribute("y", "24");
  tooltip_vbg.setAttribute("width", "24");
  tooltip_vbg.setAttribute("height", "12");
  tooltip_vbg.setAttribute("visibility", "hidden");
  tooltip_vbg.style.fill="#ffffe0";
  tooltip_vbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_vbg);
  
  tooltip_q = document.createElementNS(xmlns, 'text');
  tooltip_q.setAttribute("x","16");
  tooltip_q.setAttribute("y","1.8em");
  tooltip_q.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_q.setAttribute("visibility", "hidden");
  tooltip_q.appendChild(document.createTextNode(0));
  tooltip_grp.appendChild(tooltip_q);
  
  tooltip_v = document.createElementNS(xmlns, 'text');
  tooltip_v.setAttribute("x","16");
  tooltip_v.setAttribute("y","2.8em");
  tooltip_v.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_v.setAttribute("visibility", "hidden");
  var textNode_v = document.createTextNode(0);
  tooltip_v.appendChild(textNode_v);
  tooltip_grp.appendChild(tooltip_v);

    // Now stick the values in the run control
    $("#rl").val(pipeBits.execTime);
    $("#le").val(pipeBits.displayInt);
    $("#ts").val(pipeBits.phaseList);

    $(".unit").html(pipeBits.timeUnit);
    timeLib = {"second":1/86400,"minute":1/1440,"hour":1/24,"day":1,"unit":1,
	       "week":7,"month":365/12,"year":365};
    timeUnit = timeLib[pipeBits.timeUnit];
}
