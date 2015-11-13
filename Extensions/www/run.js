var tabs;
	$(function() {
		
	    $( "#button" ).button();
	    $( "#radioset" ).buttonset();
		
	    tabs = $( "#tabs" ).tabs({heightstyle:"fill"});
	    tabs.tabs({
		activate: function( event, ui ) {
		    if (ui.newPanel.selector != "#tabs-0") { // diagram
			lastHelper = currentHelper =
			    currentHelpers[$(ui.newPanel.selector)[0].id];
			lastIndex = tabs.tabs("option","active");
		    } else {
			currentHelper = null;
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

function clickOn(evt) {
    var tags = null;
    var blob = evt.target;
    while (tags == null) {
	tags = blob.getAttribute("id");
	blob = blob.parentNode;
    }
    var prolog = tags.match(/arc\d\d\d\d\d|node\d\d\d\d\d/);
    if (lastHelper != null && lastHelper.status != "displaying") {
	// data table status is displaying even when getting clicks
	// so must use explorer for that
	$( "#tabs" ).tabs( "option", "active", lastIndex);
	lastHelper.acceptClick(prolog[0]);
    }
}

function prettify (data, sub) {
    if (data.constructor === Object) {
	var res = [];
	for (var ind in data) {
	    res.push("#" + ind + ": " + prettify(data[ind], 1));
	}
	if (sub)
	    return "{" + res.join(" ") + "}";
	else
	    return res.join(" ");
    } else if (isFinite(data)) {
	return squeezeDigits(data, 10);
    } else {
	return data;
    }
}

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
    tooltip_v.firstChild.data = prettify(JSON.parse(values_json[prolog]), 0);
  tooltip_c.firstChild.data = model_json[prolog].comment;
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
  tooltip_cbg.setAttribute("visibility", "visible");
  tooltip_q.setAttributeNS(null,"visibility","visible");
  tooltip_v.setAttributeNS(null,"visibility","visible");
  tooltip_c.setAttributeNS(null,"visibility","visible");

  length = Math.max(tooltip_q.getComputedTextLength(),
		     tooltip_v.getComputedTextLength(),
		     tooltip_c.getComputedTextLength());
  tooltip_bd.setAttributeNS(null,"width",length+8);
  tooltip_qbg.setAttributeNS(null,"width",length+8);
  tooltip_vbg.setAttributeNS(null,"width",length+8);
  tooltip_cbg.setAttributeNS(null,"width",length+8);
}

function hoverOut() {
  tooltip_bd.setAttributeNS(null,"visibility","hidden");
  tooltip_qbg.setAttribute("visibility", "hidden");
  tooltip_vbg.setAttribute("visibility", "hidden");
  tooltip_cbg.setAttribute("visibility", "hidden");
  tooltip_q.setAttributeNS(null,"visibility","hidden");
  tooltip_v.setAttributeNS(null,"visibility","hidden");
  tooltip_c.setAttributeNS(null,"visibility","hidden");
}

function addEltAction(comp) {
  comp.addEventListener("mouseover", hoverIn);
  comp.addEventListener("mouseout", hoverOut);
  comp.addEventListener("mousedown", clickOn);
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
// now boringly find this by iteration
    for (comp in model_json) {
	if (model_json[comp].captpath.replace(/\s+/g," ") == capt) {
	    return model_json[comp].id;
	}
    }
}

function oneAfter(array, term) {
    return array[array.indexOf(term) + 1];
}

function addTabFor(species, textContent) {
    convd = textContent.replace(/}*\s+{*/g,"\"$&\"")
	.replace(/{/g,"[").replace(/}/g,"]").replace(/\s+/g,", ")
    specArray = JSON.parse("["+convd.substr(3,convd.length-6)+"]");
//    console.log("Helper key "+species+", state "+JSON.stringify(specArray));

    switch (species) {
	case "plotter1_dot_25":
	new_helper("plot");
	captArr = specArray[specArray.indexOf("/WIN/,Yvars")+1];
	captPaths = tclListOfDimty(captArr,2);
	for (x=0;x<captPaths.length;++x) {
	    if (x>0) select_for_helper("add");
	    captPathN = captPaths[x].join(" ");
//	console.log("Adding plot of " + captPathN);
// now boringly find this by iteration
	    select_for_helper(idFromCapt(captPathN));
//	    if (x==0) select_for_helper("time");
	}
	break;

	case "tabular11510":
	new_helper("table");
	captPaths = tclListOfDimty(specArray[0], 2);
	for (var i=0; i<captPaths.length; ++i) {
	    captPath = captPaths[i].join(" ");
	    select_for_helper(idFromCapt(captPath));
	}
	break;

	case "gen3d1": // lollipops
	new_helper("shapes");
	var i=3;
	currentHelper.State = [];
	while (specArray[i] != "/annotation/") {
	    template = ["lollipops"];
	    newComps = [];
	    for (parm in {"x":0,"y":0,"h":0}) {
		nId = idFromCapt(tclListOfDimty(specArray[i++],1).join(" "));
		template.push(nId);
		currentHelper.tgts.push(nId);
		newComps.push(nId);
//		currentHelper.acceptClick(idFromCapt(captPath));
	    }
	    AddTemplateToScene(currentHelper, template, newComps);
	}
	break;

	case "slide139":
	new_helper("sliders");
	break;

	case "plotterXY1_dot_0":
	new_helper("plotxy");
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
	currentHelper.State = [];
// would be done, but must convert capt paths to node ids
	for (var i=0; i<specArray.length;++i) {
	    template = [];
	    newComps = [];
	    for (var j=0; j<specArray[i].length;++j) {
		possCapt = tclListOfDimty(specArray[i][j], 1);
		if (possCapt[0][0] == "/") { // its a capt path
		    nodeId = idFromCapt(possCapt.join(" "));
		    template[j] = nodeId;
		    newComps.push(nodeId);
		    currentHelper.tgts.push(nodeId);
		} else if (possCapt[0][0] == "#") { // it's a colour
		    template[j] = possCapt[0].substr(1);
		} else { // is shape identity
		    template[j] = possCapt[0];
		}
	    }
	    AddTemplateToScene(currentHelper, template, newComps);
	}
	break;

    case "polygon375":
	new_helper("polys");
	swatArr = []
	if (oneAfter(specArray, "/WIN/,colourMapTweaked")) {
	    nswat = oneAfter(specArray, "/WIN/,nswatches");
	    for (var i=0; i<=nswat; ++i) {
		swatArr.push(oneAfter(specArray, "/WIN/,c" + i));
	    }
	    cMap = ColorMapFromSwatches(swatArr);	
	} else {
	    for (var anchor in {"bot":0,"mid":0,"top":0}) {
		swatArr.push(oneAfter(specArray, "/WIN/,c" + anchor));
		cMap = ColorMapFromPoints(nswat, swatArr[0],
					  swatArr[1], swatArr[2]);
	    }
	}
	currentHelper.nswat = nswat;
	currentHelper.cMap = cMap;
	currentHelper.bottom = parseFloat(oneAfter(specArray, "/WIN/,min"));
	currentHelper.top = parseFloat(oneAfter(specArray, "/WIN/,max"));
	for (var key in {"color":0,"xcoord":0,"ycoord":0}) {
	    capt = tclListOfDimty(oneAfter(specArray, "/WIN/," + key), 1);
	    select_for_helper(idFromCapt(capt.join(" ")));
	}
	break;

    case "grid005":
	new_helper("grid");
	if (specArray[0] == "displaying") {
	    var idx = specArray.indexOf("aspect");
	    nswat = parseInt(specArray[idx+1]);
	    currentHelper.minVal = parseFloat(specArray[idx+2]);
	    currentHelper.maxVal = parseFloat(specArray[idx+3]);
	    currentHelper.initScale =
		parseInt(specArray[specArray.indexOf("magnification")+1]);
	    idx = specArray.indexOf("swatches");
	    if (idx >= 0) {
		cMap = ColorMapFromSwatches(specArray.slice(idx+1,
								idx+nswat+2));
	    } else {
		idx = specArray.indexOf("colourmap");
		cMap = ColorMapFromPoints(nswat, specArray[idx+1],
					      specArray[idx+2],
					      specArray[idx+3]);
	    }
	    currentHelper.nswat = nswat;
	    currentHelper.cMap = cMap;
	    var captPath =  tclListOfDimty(specArray[1],1).join(" ");
	    currentHelper.acceptClick(idFromCapt(captPath));
	    if (currentHelper.status == "setting_aspect") {
		captPath =  tclListOfDimty(specArray[2],1).join(" ");
	    	currentHelper.acceptClick(idFromCapt(captPath));
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
		// alert("Helper setup file failed to parse as XML");
		// no problem, we can deal with v5 mime shfs...
		b64Bloc = returnedXML.substr(returnedXML.search("\n\n")+2);
		insList = atob(b64Bloc).split("\r\n");
		for (i=0; i<insList.length; ++i) {
		    if (insList[i].search("container")==0) {
			addTabFor(insList[i+1].replace(/\./g, "_dot_"),
				  "+++\"" + insList[i+2] + " ");
		    }
		}
		return;
	    }
	    tclHelpers = $(hlpDoc).find("container");
	    for (var i=0; i<tclHelpers.length; ++i) {
		addTabFor(tclHelpers[i].attributes.type.value,
			  tclHelpers[i].textContent);
	    }
// resize in case rows of tabs have squeezed panes
	    resize_notebook();
	}); // GetXMLHelperSetup
}

/*
  Zoom now uses d3 sorcery
  function SvgDiagZoom(factor) {
  ModDiag.setAttribute("width",factor*ModDiag.getAttribute("width"));
  ModDiag.setAttribute("height",factor*ModDiag.getAttribute("height"));
  }
*/

function scaleTimes(tList, unit) {
    tArr = tList.split(" ");
    cArr = [];
    for (i=0;i<tArr.length;++i) {
	cArr.push(tArr[i]*unit);
    }
    return cArr.join(" ");
}

var resetDepth = -2, savedStart = "stop";
function model_reset() {
    if (savedStart == "run") {
	savedStart = "stop";
	return; // exec loop will exit and call this again
    }
    note = ofInterest();
    $.ajax({
	type: "POST",
	url: "model_action.php",
	data: { "base":fileBase, "act":"Reset",
		"runlength":$("#rl").val()*timeUnit, 
		"current":0, "step":scaleTimes($("#ts").val(),timeUnit),
		"method":pipeBits.intMethod, "depth":resetDepth,
		"note":JSON.stringify(note)}
    })
	.done(function( initVals ) {
	    if (isFinite(savedStart)) { // model has been paused before run end
		$("#rl").val(parseFloat($("#rl").val())+parseFloat($("#ct").val())
			     -savedStart);
	    }
	    savedStart = "stop";
	    $("#ct").val(0);
	    $( "#progress" ).progressbar({ value: 0 });

	    initState = JSON.parse(initVals);
	    allResults = {};
	    for (var i=0; i<note.length;i++) {
		if (note[i].constructor === Object) {
		    resIndx = JSON.stringify(note[i]);
		} else {
		    resIndx = note[i];
		}
		allResults[resIndx] = initState[i];
	    }
	    update_helpers(0, allResults, false);
	    
	    $.post('model_action.php', { "base":fileBase, "act":"Report"}, 
		   function(data) {
		       values_json = JSON.parse(data);
		       // now, if this is initialization, then now is the time to set up the helpers
		       // from the .shf, as they will not be expecting an immediate update
		       if (resetDepth == -2) {
			   createInitialHelpers();
		       // finally we are ready to roll, wait is over
			   $("#WaitDialog").dialog("close");
		       }
		       resetDepth = 0;
		   }); // Report
	}); // Reset
}

function model_step(current, start, end, span) {
    if (current >= end || savedStart != "run") {
	// we are done, reset progress bar and update values
	$.post('model_action.php', { "base":fileBase, "act":"Report"}, 
	       function(data) {
		   values_json = JSON.parse(data);
	       }); // Report
	goImage = document.getElementById("button_op");
	goImage.src = "images/play.gif";
	goImage.parentNode.onclick = function () { model_exec(); };
	if (savedStart == "stop") { // reset selected during run
	    savedStart = start;
	    model_reset();
	    return;
	}
	if (current < end) {
	    savedStart = start;
	    return;
	}
	newRemain = end - start;
	newProgress = 0;
	savedStart = "stop";
    } else {
	log = parseFloat($("#le").val());
	interval = Math.min(end-current,span);
	newCurrent = current+interval;
	newRemain = end-newCurrent;
	note = ofInterest();
	execParms = {"base":fileBase, "act":"ExecuteMulti",
		     "runlength":interval*timeUnit, "current":current*timeUnit,
		     "step":scaleTimes($("#ts").val(),timeUnit),
		     "method":pipeBits.intMethod,"log":log*timeUnit,
		     "note":JSON.stringify(note)};
	// console.log(JSON.stringify(execParms));
	$.ajax({
	    type: "POST",
	    url: "model_action.php",
	    data: execParms})

	    .done(function(newVals) {
		// console.log('Data returned ' + newVals);
// now, process the values while fetching the next lot (after timeout in case
// still processing last lot)
		setTimeout(function () {
		    model_step(newCurrent, start, end, span);
		});

		var execHistory = JSON.parse(newVals);
		for (pt=0; pt<execHistory.length; pt++) {
		    timePt = execHistory[pt].slice(-1)[0]; // last value
		    var timeVal = parseFloat(timePt)/timeUnit;
		    // console.log("Displaying results for time " + timeVal);
		    allResults = {};
		    for (var i=0; i<note.length;i++) {
			if (note[i].constructor === Object) {
			    resIndx = JSON.stringify(note[i]);
			} else {
			    resIndx = note[i];
			}
			allResults[resIndx] = execHistory[pt][i];
		    }
		    setTimeout(createfunc(timeVal, allResults, true), 0);
		    // for no very obvious reason the updates are
		    // happening in the right order (at least with
		    // positive timesteps) but nothing appears on the
		    // screen till all are done -- need setTimeout.
		}
	    }); // ExecuteMulti
	$("#ct").val(newCurrent);
	newProgress = 100*(newCurrent-start)/(end-start);
    }
    $("#rl").val(newRemain);
    $( "#progress" ).progressbar({
	value: newProgress
    });
}

function createfunc(timeVal, allResults, connect) {
    return function () {update_helpers(timeVal, allResults, connect)};
}

function model_pause() {
    savedStart = "pause";
}

function model_exec() {
    goImage = document.getElementById("button_op");
    goImage.src = "images/pause.gif";
    now = parseFloat($("#ct").val());
    if (!isFinite(savedStart)) {
	start = now;
    } else {
	start = savedStart;
    }
    savedStart = "run";
    goImage.parentNode.onclick = function () { model_pause(); };
    end = now+parseFloat($("#rl").val());
    span = $("#ue").val()
    //  calibrate_helpers(end);
    model_step(now, start, end, span);
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
		    "shapes":"3-D shape viewer","grid":"Spatial grid",
		    "polys":"Polygon map"},
tabTemplate = "<li><a href='#{href}'>#{label}</a> <span class='ui-icon ui-icon-close' role='presentation'>Remove Tab</span></li>",
tabCounter = 1;

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
var lastHelper = null;
var lastIndex = null;
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
    } else if (type == "plot" || type == "plotxy") {
	currentHelper = new PlotXY(id);
	currentHelper.vers = type;
    } else if (type == "grid") {
	currentHelper = new Grid5(id);
    } else if (type == "polys") {
	currentHelper = new Polygon(id);
    }
    currentHelpers[id] = lastHelper = currentHelper;
    lastIndex = tabs.children().length - 2;
    tabs.tabs("option", "active", lastIndex);
}

function update_helpers(time, latest, connect) {
    console.log("Updating for time " + time);
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
	input.insertAdjacentHTML('afterend', max);
	if (model_json[id].units == "REAL") {
	    input.setAttribute("min", 0);
	    input.setAttribute("max", 1000);
	} else {
	    input.setAttribute("min", min);
	    input.setAttribute("max", max);
	}
	cell = row.insertCell(1);
	monitor = document.createElement("INPUT");
	monitor.setAttribute("type", "text");
	monitor.onkeydown = function (e) {
	    var evt = e || window.event;
	    // "e" is the standard behavior (FF, Chrome, Safari, Opera),
	    // while "window.event" (or "event") is IE's behavior
	    if ( evt.keyCode === 13 ) {
		id = evt.target.id.substr(4);
		slider = document.getElementById("rng_" +id);
		SetSliderValue(slider, id, evt.target.value);
		toModel(slider, id);
	    }
	};
        uniq = 'mtr_' + id;
	monitor.setAttribute("id", uniq);
	cell.appendChild(monitor);

	input.setAttribute("type", "range");
	monitor.value = values_json[id];
	SetSliderValue(input, id, monitor.value);
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

function GetSliderValue(widget) {
    //    widget = document.getElementById("rng_" + id);
    id = widget.id.substr(4);
    if (model_json[id].units == "REAL") {
	return ((1000-widget.value)*model_json[id].min +
		widget.value*model_json[id].max)/1000;
    } else {
	return widget.value;
    }
}

function SetSliderValue(widget, id, value) {
    if (model_json[id].units == "REAL") {
	widget.value = 1000*(value-model_json[id].min)
	    /(model_json[id].max-model_json[id].min);
    } else {
	widget.value = value;
    }
}

function transfer(zapTgt, entry) {
//    alert("zap " + zapTgt + " entry " + entry);
    document.getElementById(entry).value = GetSliderValue(zapTgt);
}

function toModel(zapTgt, id) {
    parmBlock = {};
    parmBlock[model_json[id].captpath] = 'NOW ' + GetSliderValue(zapTgt);
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

  $('#' + port).html("Click on components in the tree diagram to add their values to the table.<table id='" + this.port + "_table'></table>");
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

// requestAnim shim layer by Paul Irish
window.requestAnimFrame = (function(){
    return  window.requestAnimationFrame       ||
	window.webkitRequestAnimationFrame ||
	window.mozRequestAnimationFrame    ||
	window.oRequestAnimationFrame      ||
	window.msRequestAnimationFrame     ||
	function(/* function */ callback, /* DOMElement */ element){
	    window.setTimeout(callback, 1000 / 60);
	};
})();

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

    $('#' + port).html("<div id='" + port + "_drop2'></div>\
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
    
    camera.position.set(250,100,250);
    camera.lookAt(scene.position);	

    this.scene = scene;
    this.camera = camera;
    this.renderer = renderer;
    this.updated = false;

    var animate = function () {
	window.requestAnimFrame( animate );
	// cube.rotation.x += 0.1; cube.rotation.y += 0.1;
	// if ("tabs-" + $( "#tabs" ).tabs("option","active") == port)
	// above dodgy because tab id can change (eg if another deleted)
	if (currentHelper != null)
	    if (currentHelper.port == port && currentHelper.updated) {
		renderer.render(scene, camera);
		currentHelper.updated = false;
	    }
	controls.update();
    };
    var waggle = function() {
	if (currentHelper != null)
	    currentHelper.updated = true;
    };
    controls.addEventListener( 'change', waggle );
    animate();
}

function ShowMenuButton (that) {
    dropHandle = '#' + that.port + '_drop2';
    launchHandle = that.port + '_launcher2';
    menuHandle = that.port + '_menu2';
    $(dropHandle).html("\
  <div id='" + launchHandle + "_container'>\
    <button id='" + launchHandle + "'>Select new item type</button>\
  </div>\
  <ul id='" + menuHandle + "'>\
    <li id='spheres'><a href='javascript:void(0);'>Sphere</a></li>\
    <li id='lines'><a href='javascript:void(0);'>Line</a></li>\
    <li id='polygons'><a href='javascript:void(0);'>Polygon</a></li>\
    <li id='lollipops'><a href='javascript:void(0);'>Lollipop</a></li>\
    <hr>\
    <li id='ellipses'><a href='javascript:void(0);'>Ellipse</a></li>\
  </ul>");
    
    $(dropHandle).jui_dropdown({
    launcher_id: launchHandle,
    launcher_container_id: launchHandle + '_container',
    menu_id: menuHandle,
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
			"polygons":[["type","Select new item type"],
				    ["component","X vertex position lists"],
				    ["component","Y vertex position lists"],
				    ["component","Z vertex position lists"],
				    ["colour", "outline"],
				    ["colour", "fill"]],
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

function AddTemplateToScene (that, template, newComps) {
    template.push({}); // new empty display object list
    $.post('model_action.php', {"base":fileBase, "act":"Query",
				"note":JSON.stringify(newComps)},
	   function(newDataCode) {
	       oldState = that.State;
	       that.State = [template]; // New items only
	       
	       newDataArr = JSON.parse(newDataCode);
	       newData = {};
	       for (j=0; j<newComps.length; ++j) {
		   nItm = newComps[j]
		   newData[nItm] = newDataArr[j];
		   // do not use popups they may be incomplete
	       }
	       that.display(parseFloat($("#ct").val()),newData,false),
	       that.State = oldState;
	       that.State.push(template);
	   }); // Query
}

function MakeSelection (that, selected) {
//    console.log('MS ' + JSON.stringify(that));
    dropHandle = '#' + that.port + '_drop2';
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
	AddTemplateToScene(that, that.template, that.newComps);
	ShowMenuButton(that);
    } else {
	switch (that.template[i][0]) {
	case "component":
	    $(dropHandle).text('Click on component with ' + that.template[i][1] + ' of ' + that.template[0]);
	    break;
	case "colour":
	    $(dropHandle).text('Choose ' + that.template[i][1] + ' of ' + that.template[0] + ': '); // provide JSColor widget calling this back with colour
	    clr = document.createElement('INPUT')
	    // bind jscolor
	    var col = new jscolor.color(clr);
	    document.getElementById(that.port + '_drop2').appendChild(clr);
	    
	    var btn = document.createElement('button');
	    btn.innerHTML = 'OK';
	    btn.onclick = function(){
		MakeSelection(that, col.toString()); // no
		return false;
	    };
	    document.getElementById(that.port + '_drop2').appendChild(btn);
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
	case "polygons":
	    for (var old in instruct[6]) {
		this.scene.remove(instruct[6][old]);
		delete(instruct[6][old]);
	    }
	    instruct[6] = {};
	    defns = {};
	    for (i=1;i<4;++i) {
		defns[["n","xs","ys","zs"][i]] = latest[instruct[i]];
	    }
	    nC = parseInt('0x' + instruct[4]);
	    eC = parseInt('0x' + instruct[5]);
	    var polyMaterial = new THREE.MeshLambertMaterial( {color: eC} ); 
	    
	    for (var face in defns.xs) {
		var polyGeometry = new THREE.Geometry();
		var vc = 0
		for (var vertex in defns.xs[face]) {
		    polyGeometry.vertices.push(new THREE.Vector3(
			defns.xs[face][vertex],
			defns.zs[face][vertex],
			defns.ys[face][vertex]));
		    ++vc;
		    if (vc>2) {
			var newFace = new THREE.Face3(0, vc-2, vc-1);
			// newFace.color = nC;
			polyGeometry.faces.push(newFace);
		    }
		}
		// need these bits to get lighting fx to work
		polyGeometry.computeFaceNormals ();
		polyGeometry.computeVertexNormals ();
		poly = new THREE.Mesh(polyGeometry, polyMaterial);
		this.scene.add(poly);
		instruct[6][face] = poly;
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
    currentHelper.updated = true;
}

Shapes3D.prototype.resize = function (x,y) {
    this.renderer.setSize(x-50, y-120);
}

function AdjustAxesFor(that, addys) {
    for (var hdl in addys) {
	if (that.xval != 'time') {
	    if (that.xmin == undefined ||
		that.oldxs[hdl] < that.xmin) {
		that.xmin = that.oldxs[hdl];
	    }
	    if (that.xmax == undefined ||
		that.oldxs[hdl] > that.xmax) {
		that.xmax = that.oldxs[hdl];
	    }
	}
	if (that.ymin == undefined || addys[hdl] < that.ymin) {
	    that.ymin = addys[hdl];
	}
	if (that.ymax == undefined || addys[hdl] > that.ymax) {
	    that.ymax = addys[hdl];
	}
    }
    that.ly.domain([that.ymax,that.ymin]);
    if (that.xval == 'time') {
	// initialize bounds, x axis is time
	that.xmin = that.oldt;
	that.xmax = that.oldt + parseFloat($("#rl").val());
    }
    that.lx.domain([that.xmin,that.xmax]);
    that.zfn();
    that.zefn();
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

function squeezeDigits(val, room) {
    for (var p = room; p>1; --p) {
	noExp = "" + parseFloat(val.toPrecision(p));
	if (noExp.length<room) return noExp;
    }
    return val.toPrecision(room-5);
}

var xyGlbsForD3 = {};
PlotXY.prototype.acceptClick = function (compId) {
  if (this.status == "initializing") {
    this.tgts.push(compId);
    this.yvals.push(compId);
    //addys = flatten('t', JSON.parse(values_json[compId]));
    //buttonFn = "select_for_helper('time')";
    this.status = "getting_x";
    if (this.vers == 'plotxy') {  
	$('#' + this.port).html("Click on a component to plot on the X axis.");
    } else {
	select_for_helper('time')
    }
  } else if (compId == "add") {
      $('#' + this.port).find('#instruct')
	    .html("Click on a component to plot on the Y axis.");
      this.status = "adding";
  } else { // no more clicks required
      ngap = 48;
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
	if (this.xval == "time") {
	    curys = flatten("z",this.oldys);
	} else {
	    curys = this.oldys;
	}
	AdjustAxesFor(this, curys);
	return
    } else if (compId == "time") {
	this.oldt = parseFloat($("#ct").val());
	this.xval = 'time';
	xAxisName = 'time';
    } else if (this.status == "adding") {
	$('#' + this.port).find('#instruct').html(''); // delete message
	this.tgts.push(compId);
	this.yvals.push(compId);
	//addys = flatten('t', JSON.parse(values_json[compId]));
    } else { // just added component for X axis
	this.tgts.push(compId);
	this.xval = compId;
	//this.oldxs = flatten('t', JSON.parse(values_json[compId]));
	xAxisName = model_json[compId].captpath;
    }
      totes = this.tgts.length;
      if (this.xval == 'time') {
	  newComps = this.tgts.slice(totes-1,totes);
      } else {
	  newComps = this.tgts.slice(totes-2,totes);
      }
      var that = this;
      $.post('model_action.php', {"base":fileBase, "act":"Query",
				  "note":JSON.stringify(newComps)},
	     function(resp) {
		 responses = JSON.parse(resp);
		 addys = flatten('t', responses[0]);
		 if (that.xval == 'time') {
// oldys must become an array as maybe more than one var...
		     that.oldys.push(addys);
		 } else {
		     that.oldys = addys;
		     that.oldxs = flatten('t', responses[1]);
		 }
		 AdjustAxesFor(that, addys);
		 
	     });
		 
      if (this.xval == 'time') { // x axis is time
	  if (this.status == "adding") {
	      this.status = "displaying";
// adjust y axis for range of new addition, then we are done
	      return;
	  }
      }
      this.status = "displaying";
      
      var x = d3.scale.linear()
	  .domain([0,100]) // placeholders -- set by callback
	  .range([ngap, w+ngap]);
      var y = d3.scale.linear()
	  .domain([100,0])
	  .range([0, h]);
      var xAxis = d3.svg.axis()
	  .scale(x)
	  .tickSize(-h)
          .tickFormat(function(t) {return squeezeDigits(t, 7)})
	  .orient("bottom");
      var yAxis = d3.svg.axis()
	  .scale(y)
	  .tickSize(-w)
          .tickFormat(function(t) {return squeezeDigits(t, 7)})
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
          .attr("id", this.port + "_xscale")
	  .attr("class", "pane")
	  .attr("y",h)
	  .attr("width", w+ngap)
	  .attr("height", ngap)
	  .call(zoomxaxis);
      this.svg.append("rect") // y scale
          .attr("id", this.port + "_yscale")
	  .attr("class", "pane")
	  .attr("width", ngap)
	  .attr("height", h)
	  .call(zoomyaxis);
      this.svg.append("rect") // port
          .attr("id", this.port + "_view")
	  .attr("class", "pane")
          .attr("x", ngap)
	  .attr("width", w)
	  .attr("height", h)
	  .call(zoomport);
      redraw(portStr,yAxis,xAxis);

      this.ttdiv = d3.select('#' + this.port).append("div")   
          .attr("id", this.port + "_tt")
	  .attr("class", "tooltip")               
	  .style("opacity", 0);

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
    ngap = 48;
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
    // now move the target areas for rescaling
    d3.select('#' + this.port + "_xscale")
	.attr("y",h)
	.attr("width", w+ngap);
    d3.select('#' + this.port + "_yscale")
	.attr("height", h);
    d3.select('#' + this.port + "_view")
	.attr("width", w)
	.attr("height", h);
}

function hoverInTrace(that, d) {
    that.ttdiv.transition()        
	.duration(200)      
	.style("opacity", .9);
    forLines = "42px";
    bloc = d[1].i;
    if (isFinite(bloc.seq)) {
	msg = "Time: " + bloc.seq;
    } else {
	msg = model_json[bloc.seq].text;
    }
    inds = bloc.idxs.substr(0,bloc.idxs.length-2);
    if (inds.indexOf(",")>-1) {
	msg += "<br>Indices: " + inds;
    } else if (inds.length > 0) {
	msg += "<br>Index: " + inds;
    } else {
	forLines = "28px";
    }
    msg += "<br>Run: " + (bloc.run+1);
    that.ttdiv.html(msg)  
	.style("left", (d3.event.layerX + 10) + "px")     
	.style("top", (d3.event.layerY + 10) + "px")
	.style("height", forLines);
       
    //console.log("Moused over a trace");
}

PlotXY.prototype.display = function (time, latest, connect) {
    var that = this; // for tooltip functions
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
				{"y":newys[hdl],"x":newxs[hdl],
				 "i":{"seq":time,"idxs":hdl,"run":this.nrun}}]);
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
				{"y":newys[hdl],"x":time,
				 "i":{"seq":this.yvals[i],"idxs":hdl,
				      "run":this.nrun}}]);
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
	      var col = "blue orange green brown purple red black DeepSkyBlue HotPink ForestGreen".split(" ")[this.yvals.length*this.nrun+i];
	      newGrp = this.svg.append("g")
		  .attr("class", "step"); // new group for this time step's data
	      newGrp.selectAll(".line") // selects empty set?
		  .data(idxs[i])
		  .enter().append("path")
		  .attr("class", "trace")
		  .attr("stroke-width",3)
		  .attr("stroke","white")
		  .attr("d", this.line)
		  .on("mouseover", function(d) {
		      hoverInTrace(that, d);
		  })
		  .on("mouseout", function(d) {       
		      that.ttdiv.transition()        
			  .duration(500)      
			  .style("opacity", 0);   
		  });
	      newGrp2 = this.svg.append("g")
		  .attr("class", "step"); // new group for this time step's data
	      newGrp2.selectAll(".line") // selects empty set?
		  .data(idxs[i])
		  .enter().append("path")
		  .attr("class", "trace")
		  .attr("stroke-width",1)
		  .attr("stroke",col)
		  .attr("d", this.line)
		  .on("mouseover", function(d) {
		      hoverInTrace(that, d);
		  })
		  .on("mouseout", function(d) {       
		      that.ttdiv.transition()        
			  .duration(500)      
			  .style("opacity", 0);   
		  });
	  }
      } else {
	  ++this.nrun;
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
var legenData = "+gADCBhAoICBAwgSKFjAoIGDBxAiSJhAoYKFCxgyaNjAoYOHDyBCiBhBooSJEyhSqFjBooWLFzBiyJhBo4aNGzhy6NjBo4ePH0CCCBlCpIiRI0iSKFnCpImTJ1CiSJlCpYqVK1iyaNnCpYuXL2DCiBlDpoyZM2jSqFnDpo2bN3DiyJlDp46dO3jy6NnDp4+fP4ACCRpEqJChQ4gSKVrEqJGjR5AiSZpEqZKlS5gyadrEqZOnT6BCiRpFqpSpU6hSqVrFqpWrV7BiyZpFq5atW7hy6drFq5evX8CCCRtGrJixY8iSKVvGrJmzZ9CiSZtGrZq1a9iyadvGrZv6t2/gwokbR66cuXPo0qlbx66du3fw4smbR6+evXv48unbx6+fv3//CESQQQgpxJBDEElEkUUYacSRRyCJRJJJKKnEkkswyUSTTTjpxJNPQAlFlFFIKcWUU1BJRZVVWGnFlVdgiUWWWWipxZZbcMlFl1146cWXX4AJRphhiCnGmGOQSUaZZZhpxplnoIlGmmmoqcaaa7DJRpttuOnGm2/ACUecccgpx5xz0ElHnXXYacedd+CJR5556KnHnnvwyUefffjpx59/AApY0EEJLdTQQxFNVNFFGW3U0UchjVTSSSmt1NJLMc1U00057dTTT0ENVdRRSS3V1FNRTfpV1VVZbdXVV2GNVdZZaa3V1ltxzVXXXXnt1ddfgQ1W2GGJLdbYY5FNVtllmW3W2WehjVbaaamt1tprsc1W22257dbbb8ENV9xxyS3X3HPRTVfdddlt19134Y1X3nnprdfee/HNV999+e3X338BDjRogYYimOiCjDr4aISSUljphZhquGmHnoIY6oikmnhqiqqy2OqLsMo4a4224pjrjrz6+GuQwhJZ7JHIKrlsk85CGe2U1Fp5bZbactntl+CKOW6Z5qKZ7prsuvlunPLSWe+d+Oq5b5/+AhrwgIQaeGiCijLY6IOQSjhphZZimOmGnHr4aYiikljqiaiq+rhqi67CGOuMtNp4a4668tjrj8AKOWyRxiKZ7JLMOvlslNJSWe2V2Gq5bZfeghnumOSaeW6a6rLZ7pvwyjlvnfbime+e/Pr5b6ACE1jogYgquGiDjkIY6YSUWnhphppy2OmHoIo4aommopjqiqy6+GqMstJY64246rhrj74CGeyQxBp5bJLKMtnsk9BKOW2V1mKZ7ZbcevltmOKSWe6Z6Kq5bpvuwhnvnPTaeW+e+vLZ758AE5TrtGYw2XlNYbYTm8N0ZzaJ+U5tFhOe2zRmPLl5THl2E5nz9GYy6flNZdYTnMu0ZziZeU9xNhOf43RmPsn5TH2WE5r7NGdrNPl5Tmn2E53T9Gc6qflPdVYTYNYKFruuJax2YWtY7soWsd6lrWLBa1vGihe3jiWvbiFrXt5KFr2+pax6gWtZ9goXs+4lrmbha1zOyhe5nqWvckFrX+aKFr/OJa1+oWta/koXtf6lrmoACwgAOw==";

function AlterRange(that, factor) {
    that.bottom = that.bottom * factor;
    that.top = that.top * factor;
}

function BytesFromHex (hex) {
    if (hex.length > 12) {
	R = parseInt(hex.substr(1,2),16);
	G = parseInt(hex.substr(5,2),16);
	B = parseInt(hex.substr(9,2),16);
    } else {
	R = parseInt(hex.substr(1,2),16);
	G = parseInt(hex.substr(3,2),16);
	B = parseInt(hex.substr(5,2),16);
    }
    return {"R":R,"G":G,"B":B};
}

function ColorMapFromPoints (n, bot, mid, top) {
    specials = ["black", "red", "green", "white"];

    data = [];
    for (var x=0; x<3; ++x) {
	hiPt = [bot, mid, top][x];
	var c = specials.indexOf(hiPt);
	if (c > -1) {
	    hi = {R:[0,255,0,255][c],G:[0,0,255,255][c],B:[0,0,0,255][c]};
	} else {
	    hi = BytesFromHex(hiPt);
	}
	if (x>0) {
	    for (var j=0; j<128; ++j) {
		if (n==1) {
		    fract = x-1;
		} else {
		    fract = 1+2*Math.floor(n*(j+128*(x-1))/256)/(n-1)-x;
		}
		var r = Math.round(fract*hi.R+(1-fract)*lo.R);
		var g = Math.round(fract*hi.G+(1-fract)*lo.G);
		var b = Math.round(fract*hi.B+(1-fract)*lo.B);
		data += String.fromCharCode(r, g, b);
	    }
	}
	lo = hi;
    }
    return data;
}

function ColorMapFromSwatches (swList) {
    var data = [];
    for (var i=0; i<swList.length; ++i) {
	c = BytesFromHex(swList[i]);
	for (var j=Math.floor(i*256/swList.length);
	     j<Math.floor((i+1)*256/swList.length); ++j) {
	    data += String.fromCharCode(c.R, c.G, c.B);
	}
    }
    return data;
}

function Polygon (port) {
    this.port = port;
    this.tgts = [];
    this.status = "initializing";

    this.nswat = 32;
    this.cMap = ColorMapFromPoints(this.nswat, "black", "green", "white");
    this.bottom = 0;
    this.top = 100;
    this.initScale = 1;

    var that = this;
    bar = d3.select('#' + port).append("div").attr("id", port + "_Buttonbar")
        .style('width','100%');
    bar.append("button").html("<img src='images/less.gif'/>")
	.style('float','left').on('click', function() {AlterRange(that, 0.5) });
    bar.append("button").html("<img src='images/greater.gif'/>")
	.style('float','left').on('click', function() {AlterRange(that, 2.0) });
    bar.append("div").attr("id", port + "_instruct").style('float','left');
    
    this.scaleGrp = d3.select('#' + port).append("svg")
	.attr("width",800).attr("height",480).attr("id", port + "_diag")
	.append("g");
    this.diagZoom = d3.behavior.zoom()
	.on("zoom", function () {
	    d3.select('#' + port + '_diag').select('g')
		.attr("transform", "translate(" + d3.event.translate +
		      ")scale(" + d3.event.scale + ")");
	});
    d3.select('#' + port + '_diag').attr("class","pane").call(this.diagZoom);
    d3.select('#' + port + '_instruct').html("Select component with values to display as polygon colours");
}

function colorFrom(map, line) {
    colSpec = "#";
    line = Math.min(Math.max(line, 0), 255);
    for (j=0;j<3;++j) {
	s = map.charCodeAt(3*line+j).toString(16);
	if (s.length<2)
	    colSpec = colSpec + "0"; // pad
	colSpec = colSpec + s;
    }

    return colSpec;
}

Polygon.prototype.acceptClick = function (nodeId) {
    var that = this; // no chance..
    if (this.status == "initializing") {
	this.tgts[0] = nodeId;
	this.status = "getting_x_coords";
	d3.select('#' + this.port + '_instruct').html("Select component with values for X coordinates of verices");
    } else if (this.status == "getting_x_coords") {
	this.xpts = nodeId; // not tgts[1] we lose interest having got them
	this.status = "getting_y_coords";
	d3.select('#' + this.port + '_instruct').html("Select component with values for Y coordinates of verices");
    } else {
    headerData = 'GIF89a';
    headerData += conv16(256);                  // image width
    headerData += conv16(8);                  // image height

    headerData += String.fromCharCode(0xf7, 0, 0);
    // colour table, background colour, pixel aspect ratio

    //black -> red -> white
    headerData += this.cMap;

    headerData += String.fromCharCode(0x2c); // image descriptor
    headerData += conv16(0);                  // NW corner position of image
    headerData += conv16(0);                  // in logical screen
    headerData += conv16(256);                  // image width
    headerData += conv16(8);                  // image height
    headerData += String.fromCharCode(0, 8);

    keyDiv = document.createElement("div");
    keyDiv.style.width = "100%";
    this.lowLabel = document.createElement("label");
    this.lowLabel.style.width = "4%";
    this.lowLabel.innerHTML = this.bottom.toPrecision(3);
    this.legend = document.createElement("img");
    this.legend.style.width = "90%";
    this.legend.style.height = "16px";
    this.legend.style.padding = "4px";
    this.hiLabel = document.createElement("label");
    this.hiLabel.style.width = "4%";
    this.hiLabel.innerHTML = this.top.toPrecision(3);

    document.getElementById(this.port).appendChild(keyDiv);
    keyDiv.appendChild(this.lowLabel);
    keyDiv.appendChild(this.legend);
    keyDiv.appendChild(this.hiLabel);
    this.legend.src = 'data:image/gif;base64,'
	+ btoa(headerData) + legenData;
    this.legend.alt = "Something has gone terrubly winf";

	this.ypts = nodeId;
	this.status = "displaying";
	d3.select('#' + this.port + '_instruct').html("");

	lookAt = [this.tgts[0],this.xpts,this.ypts];
	newTitle = model_json[this.tgts[0]].text + ' -- polygon map';
	$('#tabs a[href=#' + this.port + ']').text(newTitle);
	$.post('model_action.php', {"base":fileBase, "act":"Query",
				    "note":JSON.stringify(lookAt)},
	   function(resp) {
	       colScaler = 255/(that.top-that.bottom); 
	       responses = JSON.parse(resp);
	       colours = flatten('m', responses[0]);
	       for (var inds in colours) {
		   indArr = inds.split(",");
		   niceInds = indArr.join("_");
		   xObj = responses[1];
		   yObj = responses[2];
		   for (i=0; i<indArr.length-1; i++) { // last ind is 'm'
		       xObj = xObj[indArr[i]];
		       yObj = yObj[indArr[i]];
		   }
		   // now they should be straight arrays..not
		   pts = "";
		   for (var j in yObj) {
		       pts = pts + xObj[j] + "," + -yObj[j] + " ";
		   }
		   colFract = Math.floor((colours[inds]-that.bottom)*colScaler);

		   // OK now add the poligonnn

		   colSpec = colorFrom(that.cMap, colFract);
		   that.scaleGrp.append("polygon")
		       .attr("id", that.port + niceInds).attr("points",pts)
		       .attr("fill",colSpec).attr("stroke","black")
		       .attr("stroke-width",0);
	       }
	       bbox = that.scaleGrp[0][0].getBBox();
	       // console.log(JSON.stringify(bbox));
	       initScale = 800/bbox.width;
	       that.diagZoom.translate([-initScale*bbox.x,-initScale*bbox.y])
		   .scale(initScale);
	       grpAttr = "translate("+-initScale*bbox.x+","+-initScale*bbox.y+
		   ")scale("+initScale+","+initScale+")";
	       that.scaleGrp.attr("transform",grpAttr);
	   }); // Query
    } 
}

Polygon.prototype.resize = function (x, y) {
//   if (this.status != "displaying") return;
//   console.log('Tab width: ' + d3.select('#' + this.port).style('width'));
//   console.log('Notebook height: ' + d3.select('#tabs').style('height'));
    ngap = 40;
//      w = 800;
      w = x-ngap;
//      h = 800;
      h = y-60-ngap;
    d3.select('#' + this.port + '_diag').attr("width",w).attr("height",h);
}

Polygon.prototype.display = function (time, latest, connect) {
    newColours = flatten('m', latest[this.tgts[0]]);
    colScaler = 255/(this.top-this.bottom); 
    for (inds in newColours) {
	colFract = Math.floor((newColours[inds]-this.bottom)*colScaler);
	colSpec = colorFrom(this.cMap, colFract);
	niceInds = inds.split(",").join("_");
	d3.select('#' + this.port + niceInds).attr("fill",colSpec);
    }
    this.lowLabel.innerHTML = "" + this.bottom;
    this.hiLabel.innerHTML = "" + this.top;
}

function Grid5 (port) {
    this.port = port;
    this.tgts = [];
    this.status = "initializing";

    this.nswat = 32;
    this.cMap = ColorMapFromPoints(this.nswat, "black", "red", "white");
    this.minVal = 0;
    this.maxVal = 100;
    this.initScale = 1;

    var that = this;
    bar = d3.select('#' + port).append("div").attr("id", port + "_Buttonbar")
        .style('width','100%');
    bar.append("button").html("<img title='Reduce range' src='images/less.gif'/>")
	.style('float','left').on('click', function() {AlterRange(that.tgts[0], 0.5) });
    bar.append("button").html("<img title='Increase range' src='images/greater.gif'/>")
	.style('float','left').on('click', function() {AlterRange(that.tgts[0], 2.0) });
    bar.append("div").attr("id", port + "_instruct").style('float','left');
    
    this.scaleGrp = d3.select('#' + port).append("svg")
	.attr("width",800).attr("height",480).attr("id", port + "_diag")
	.append("g");
    this.diagZoom = d3.behavior.zoom()
	.on("zoom", function () {
	    d3.select('#' + port + '_diag').select('g')
		.attr("transform", "translate(" + d3.event.translate +
		      ")scale(" + d3.event.scale + ")");
	});
    d3.select('#' + port + '_diag').attr("class","pane").call(this.diagZoom);
    d3.select('#' + port + '_instruct').html("Select component with values to display in grid");
    this.scaleGrp.append("svg:image")
	.attr("id", port + "_img")
	.attr("width","49px")
	.attr("height","49px")
	.attr("xlink:href", "images/bigsimile.gif");
}

Grid5.prototype.resize = function (x, y) {
//   if (this.status != "displaying") return;
//   console.log('Tab width: ' + d3.select('#' + this.port).style('width'));
//   console.log('Notebook height: ' + d3.select('#tabs').style('height'));
    ngap = 40;
//      w = 800;
      w = x-ngap;
//      h = 800;
      h = y-60-ngap;
    d3.select('#' + this.port + '_diag').attr("width",w).attr("height",h);
}

Grid5.prototype.acceptClick = function (nodeId) {
    var that = this; // no chance..
    if (this.status == "initializing") {
	this.tgts[0] = {"format":"binary","node":nodeId,
			"bottom":this.minVal,"top":this.maxVal,
			"nswat":this.nswat};
	dims = model_json[nodeId].dims;
	this.height = dims[0];
	this.hex = (model_json[model_json[nodeId].parent].eval == "HONEYCOMB");
	
	if (dims.length == 3 && !isNaN(parseInt(dims[0])) 
	    && !isNaN(parseInt(dims[1]))) {
	    this.width = dims[1];
	} else {
	    d3.select('#' + this.port + '_instruct').html("Select component with values corresponding to grid columns");
	    this.status = "setting_aspect";
	    return;
	}
    } else if (this.status == "setting_aspect") {
	// now we need to get the unique value count and the grid data, and
	// draw once we have both...later...also how ro get n of values?
// 	$.post('model_action.php',
// 	       {"base":fileBase, "act":"Query",
// 		"note":JSON.stringify({"node":nodeId, "format":"distinct"})},
// 	       function(distCount) {
// 		   that.width = parseInt(distCount);
// 		   that.height = that.height/that.width;
	// 	       });
	note = [{"node":nodeId, "format":"distinct"}];
    } else {
	note = [];
    }
    
    d3.select('#' + this.port + '_instruct').html("");
    this.diagZoom.translate([0,0]).scale(this.initScale);
    grpAttr = "translate(0,0)scale("+this.initScale+","+this.initScale+")";
    this.scaleGrp.attr("transform",grpAttr);
    // new version, tries to do GIF
    newTitle = model_json[this.tgts[0].node].text + ' -- spatial grid';
    $('#tabs a[href=#' + this.port + ']').text(newTitle);
    note.push(this.tgts[0]);
    $.post('model_action.php', {"base":fileBase, "act":"Query",
				"note":JSON.stringify(note)},
	   function(resp) {
	       responses = JSON.parse(resp);
	       if (that.status == "setting_aspect") {
		   that.width = parseInt(responses[0]);
		   that.height = Math.floor(that.height/that.width);
		   arrInd = 1;
	       } else {
		   arrInd = 0;
	       }
	       // GIF header
	       data = 'GIF89a';
	       data += conv16(that.width);                  // image width
	       data += conv16(that.height);                  // image height
	       
	       data += String.fromCharCode(0xf7, 0, 0);
	       // colour table, background colour, pixel aspect ratio
	       
	       //black -> red -> white
	       data += that.cMap;

	       // now add a graphix control xtn to declare 00 transparent
	       data += String.fromCharCode(0x21, 0xf9, 0x04, 0x01,
					   0,0,0,0);
	       // right that's 789 bits and we have 11 to go making 800 --
	       // nice and round but we want a multiple of 3 to hit a
	       // base64 char boundary, so add a comment extn to do it
	       data += String.fromCharCode(0x21, 0xfe, 9);
	       data += "SimiLive!";
	       data += String.fromCharCode(0);
	       
	       data += String.fromCharCode(0x2c); // image descriptor
	       data += conv16(0);                 // NW corner position of image
	       data += conv16(0);                 // in logical screen
	       data += conv16(that.width);                  // image width
	       data += conv16(that.height);                  // image height
	       data += String.fromCharCode(0, 8); //  no-local-colour-table,
	       // lzw-minimum-code-size
	       
	       that.headerGIF = 'data:image/gif;base64,' + btoa(data);

	       that.status = "displaying";
	       d3.select('#' + that.port + '_img')
		   .attr("width",that.width).attr("height",that.height)
		   .attr("transform","translate(0," + that.height + ")scale(1,-1)")
		   .attr("xlink:href", that.headerGIF + responses[arrInd]);
	       if (that.hex) {
		   d3.select('#' + that.port + '_img')
		       .attr("transform","scale(1.732,1.5)"); 
	       }
	   }); // Query

    headerData = 'GIF89a';
    headerData += conv16(256);                  // image width
    headerData += conv16(8);                  // image height

    headerData += String.fromCharCode(0xf7, 0, 0);
    // colour table, background colour, pixel aspect ratio

    //black -> red -> white
    headerData += this.cMap;

    headerData += String.fromCharCode(0x2c); // image descriptor
    headerData += conv16(0);                  // NW corner position of image
    headerData += conv16(0);                  // in logical screen
    headerData += conv16(256);                  // image width
    headerData += conv16(8);                  // image height
    headerData += String.fromCharCode(0, 8);

    keyDiv = document.createElement("div");
    keyDiv.style.width = "100%";
    this.lowLabel = document.createElement("label");
    this.lowLabel.style.width = "4%";
    this.lowLabel.innerHTML = this.minVal.toPrecision(3);
    this.legend = document.createElement("img");
    this.legend.style.width = "90%";
    this.legend.style.height = "16px";
    this.legend.style.padding = "4px";
    this.hiLabel = document.createElement("label");
    this.hiLabel.style.width = "4%";
    this.hiLabel.innerHTML = this.maxVal.toPrecision(3);

    zone = document.getElementById(this.port);
    zone.style.imageRendering = "pixelated";
    zone.appendChild(keyDiv);
    
    keyDiv.appendChild(this.lowLabel);
    keyDiv.appendChild(this.legend);
    keyDiv.appendChild(this.hiLabel);
    this.legend.src = 'data:image/gif;base64,'
	+ btoa(headerData) + legenData;
    this.legend.alt = "Something has gone terrubly winf";
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
	.attr("xlink:href", this.headerGIF + arr);
    this.lowLabel.innerHTML = this.tgts[0].bottom.toPrecision(3);
    this.hiLabel.innerHTML = this.tgts[0].top.toPrecision(3);
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
	      .on('hover_node.jstree',function(e,data){
		  // console.log('Hovered ' + data.node.id);
		  $("#"+data.node.id).prop('title', values_json[data.node.id]);
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
		 }); // LoadSPF
      }); // Describe

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
    }); // Parameterize
//    resetDepth = -1;
// needed because setting in callback fn above seems oddly to be out of scope
}

// window.onbeforeunload = function(e) {
//   return 'Warning: model state will be lost if you leave the site!';
// };
window.onunload = function(e) {
    $.post('model_action.php', { "act":"Exit", "base":fileBase});
};

var pipeBits;
////////////////////////////////////// PREPARE /////////////////////////////
var xmlns = 'http://www.w3.org/2000/svg';
var tooltip_grp;
var tooltip_bd;
var tooltip_qbg;
var tooltip_vbg;
var tooltip_cbg;
var tooltip_q;
var tooltip_v;
var tooltip_c;
var ModDiag;
var model_json;
var values_json;
var fvParms;
var timeUnit = "unit";
var diag_zoom;
function prepare() {
    // display the loading, please wait screen
    $( "#WaitDialog" ).dialog({
	autoOpen: true,
	width: 400,
	modal: true,
    });
    // remove the title bar
    $(".ui-dialog-titlebar").hide();
    
$.post('model_action.php', {"act":"BuildShareLib", "base":fileBase},
       function(execParms) {
	   console.log("BSL returns " + execParms);
	   pipeBits = JSON.parse(execParms);

	   // Now stick the values in the run control
	   $("#rl").val(pipeBits.execTime);
	   $("#ue").val(pipeBits.displayInt);
	   $("#le").val(pipeBits.displayInt);
	   $("#ts").val(pipeBits.phaseList);
	   
	   $(".unit").html(pipeBits.timeUnit);
	   timeLib = {"second":1/86400,"minute":1/1440,"hour":1/24,"day":1,
		      "unit":1,"week":7,"month":365/12,"year":365};
	   timeUnit = timeLib[pipeBits.timeUnit];

	// Version using UNIX sockets -- add .uxs extension to model name base
	   $.post('model_action.php', {"act":"CreateSocket", "base":fileBase},
		  function(spew) {
		      console.log("Socket created: " + spew);
		      //           populateStructs();
		  }); // CreateSocket

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
		  }); // WaitSocket
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
          addEltAction(element);
      }
    }
    ModDiag.appendChild(tooltip_grp);
  }); // GetSVG
       }); // BuildShareLib
  // Create a path in SVG's namespace
  tooltip_grp = document.createElementNS(xmlns,'g');
  tooltip_bd = document.createElementNS(xmlns,'rect');
  tooltip_bd.setAttribute("x", "12");
  tooltip_bd.setAttribute("y", "12");
  tooltip_bd.setAttribute("width", "24");
  tooltip_bd.setAttribute("height", "36");
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
  tooltip_vbg.setAttribute("y", "36");
  tooltip_vbg.setAttribute("width", "24");
  tooltip_vbg.setAttribute("height", "12");
  tooltip_vbg.setAttribute("visibility", "hidden");
  tooltip_vbg.style.fill="#ffffe0";
  tooltip_vbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_vbg);
  
  tooltip_cbg = document.createElementNS(xmlns,'rect');
  tooltip_cbg.setAttribute("x", "12");
  tooltip_cbg.setAttribute("y", "24");
  tooltip_cbg.setAttribute("width", "24");
  tooltip_cbg.setAttribute("height", "12");
  tooltip_cbg.setAttribute("visibility", "hidden");
  tooltip_cbg.style.fill="#ffe0c0";
  tooltip_cbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_cbg);
  
  tooltip_q = document.createElementNS(xmlns, 'text');
  tooltip_q.setAttribute("x","16");
  tooltip_q.setAttribute("y","1.8em");
  tooltip_q.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_q.setAttribute("visibility", "hidden");
  tooltip_q.appendChild(document.createTextNode(0));
  tooltip_grp.appendChild(tooltip_q);
  
  tooltip_v = document.createElementNS(xmlns, 'text');
  tooltip_v.setAttribute("x","16");
  tooltip_v.setAttribute("y","3.8em");
  tooltip_v.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_v.setAttribute("visibility", "hidden");
  var textNode_v = document.createTextNode(0);
  tooltip_v.appendChild(textNode_v);
  tooltip_grp.appendChild(tooltip_v);
  
  tooltip_c = document.createElementNS(xmlns, 'text');
  tooltip_c.setAttribute("x","16");
  tooltip_c.setAttribute("y","2.8em");
  tooltip_c.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_c.setAttribute("visibility", "hidden");
  tooltip_c.appendChild(document.createTextNode(0));
  tooltip_grp.appendChild(tooltip_c);
}
