var runningInClient = true;

$(function() {
		
	    $( "#button" ).button();
	    $( "#radioset" ).buttonset();
		
		

		

		

		
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

// experimental jqueryui popup dialogue implementation
         $(function() {
            $( "#dialog-1" ).dialog({
               autoOpen: false,  
               title: "File parameters",
            });
            $( "#opener" ).click(function() {
		$( "#dialog-1" ).dialog( "open" );
		if ($( "#dialog-1" ).html() == "empty") {
		    insert_helper("dialog-1", "params");
		}
            });
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

function binary_from_local(prolog, min, max) {
    c_result = Module.ccall('get_raw_values', 'number', ['string', 'number'],
			    [prolog, modelInstance]);
    var ddims = Module.ccall('ds_from_nodvals', 'number', ['number'], [c_result]);
    var vals = Module.ccall('ct_from_nodvals', 'number', ['number'], [c_result]);
    final = "";
    var rows = getValue(ddims, 'i32');
    var cols = getValue(ddims+4, 'i32');
    for (var i = 0; i < rows; ++i) {
	for (var j = 0; j < cols; ++j) {
	    if (model_json[prolog].type == "REAL") {
		modelFloat = getValue(vals+8*(cols*i + j), 'double');
	    } else {
		modelFloat = getValue(vals+4*(cols*i + j), 'i32');
	    }
	    final += String.fromCharCode(255.9999*((modelFloat-min)/(max-min)));
	}
	while(j<4*Math.ceil(j/4)) {
	    final += " ";
	    ++j;
	}
    }
    Module.ccall('free_bloc_data', 'number', ['number', 'number'],
		 [vals, ddims]);
    _free(c_result);
    
    return final;
}

function js_from_local_model(prolog, howMany) {
    c_result = Module.ccall('get_raw_values', 'number', ['string', 'number'],
			    [prolog, modelInstance]);
    if (c_result) {
//	console.log("Values retrieved OK");
    } else {
	console.log("Component has no data");
	return;
    }
    var ddims = Module.ccall('ds_from_nodvals', 'number', ['number'], [c_result]);
    var vals = Module.ccall('ct_from_nodvals', 'number', ['number'], [c_result]);

    msbs_dims = [];
    var sbList = MakeSubBlockSizes(ddims);
//    console.log("Sub-blocks:", JSON.stringify(sbList),
//		"Dims:", JSON.stringify(msbs_dims));
    var final = convert_to_js(msbs_dims, sbList, vals, [howMany]);
    Module.ccall('free_bloc_data', 'number', ['number', 'number'],
		 [vals, ddims]);
    _free(c_result);
    
    return final;
}

function hoverIn(evt) {
  var tags = null;
  var blob = evt.target;
  while (tags == null) {
    tags = blob.getAttribute("id");
    blob = blob.parentNode;
  }
    var prolog = tags.match(/arc\d\d\d\d\d|node\d\d\d\d\d/);
    if (prolog == null) {
	// console.log("No prolog id for " + evt.target);
	return;
    }
//    subtlety = evt.path;
//  var currentLine = model_json.find(function (e) {
//		     return e.id == prolog;
// 		     });
  tooltip_q.firstChild.data = model_json[prolog].equation;
    
    // tooltip_v.firstChild.data = prettify(JSON.parse(values_json[prolog]), 0);
    // OK, try getting data from built-in model instead
    tooltip_v.firstChild.data = prettify(js_from_local_model(prolog[0], 1000));
    tooltip_c.firstChild.data = model_json[prolog].comment;
// above will break function if it doesn't work

// now find svg node...cannot use below cos safari does not supply evt.path
//    for (var i=0; subtlety[i].nodeName != "svg"; ++i) {}
//        var uupos = subtlety[i].createSVGPoint();
	while (blob.nodeName != "svg") {
           topGrp = blob;
	   blob = blob.parentNode;
	}
	var uupos = blob.createSVGPoint();
        uupos.x = evt.pageX - window.pageXOffset;
        uupos.y = evt.pageY - window.pageYOffset;
//        var ctm = subtlety[i-1].getScreenCTM();
	var ctm = topGrp.getScreenCTM();
        if (ctm = ctm.inverse())
            uupos = uupos.matrixTransform(ctm);

  //tooltip_grp.setAttributeNS(null,"transform",
// 			     "translate(" + uupos.x + "," + uupos.y + ")scale("
    // 			     + tooltip_scale + ")");
    tooltip_grp.setAttributeNS(null,"transform",
			       "translate(" + uupos.x + "," + uupos.y + ")scale(1.0)");
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

function setupHelperIn(win, species, textContent) {
    convd = textContent.replace(/}*\s+{*/g,"\"$&\"")
	.replace(/{/g,"[").replace(/}/g,"]").replace(/\s+/g,", ")
    specArray = JSON.parse("["+convd.substr(3,convd.length-6)+"]");
//    console.log("Helper key "+species+", state "+JSON.stringify(specArray));

    switch (species) {
	case "plotter1_dot_25":
	insert_helper(win, "plot");
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
	insert_helper(win, "table");
	captPaths = tclListOfDimty(specArray[0], 2);
	for (var i=0; i<captPaths.length; ++i) {
	    captPath = captPaths[i].join(" ");
	    select_for_helper(idFromCapt(captPath));
	}
	break;

	case "gen3d1": // lollipops
	insert_helper(win, "shapes");
	var i=3;
	currentHelper.State = [];
	lolliCount = 0;
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
	insert_helper(win, "sliders");
	break;

	case "plotterXY1_dot_0":
	insert_helper(win, "plotxy");
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
	insert_helper(win, "shapes");
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
	insert_helper(win, "polys");
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
	insert_helper(win, "grid");
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
    case "ModelDiagram20060804":
	insert_helper(win, "diagram");
	break;
    default:
	console.log("Cannot emulate Tcl helper: " + species);
	return false;
    }
    return true;
}

function createInitialHelpers() {
// convert Simile XML-style helper setup into a set of tabs on the client

// First get the XML from the server
//     $.ajax({
// 	type: "POST",
// 	url: "model_action.php",
// 	data: { "base":fileBase, "act":"GetXMLHelperSetup"}
//     })
// 	.done(function( returnedXML ) {
    // 	    if (returnedXML == '') return;
    if (typeof(returnedXML) == 'undefined') {
	helperElt = {nodeName:'notebook',children:[]};
    } else {
	parser=new DOMParser();
	hlpDoc = parser.parseFromString(returnedXML, "text/xml");
		if ($(hlpDoc).find("parsererror").length > 0) {
		    // alert("Helper setup file failed to parse as XML");
		    // no problem, we can deal with v5 mime shfs...
		    // (but only old-style tab-per-helper)
		    b64Bloc = returnedXML.substr(returnedXML.search("\n\n")+2);
		    insList = atob(b64Bloc).split(/\r?\n/);
		    for (i=0; i<insList.length; ++i) {
			if (insList[i].search("container")==0) {
			    chType = insList[i+1].replace(/\./g, "_dot_");
			    chState = "+++\"" + insList[i+2] + " ";
			    chSpec = {nodeName:"container",
				      attributes:{type:{value:chType}},
				      textContent:chState};
			    tabSpec = {attributes:{caption:{value:'Tab '
					+ (helperElt.children.length+1)}},
				       children:[chSpec]};
			    helperElt.children.push(tabSpec);
						     
			    //addTabFor(insList[i+1].replace(/\./g, "_dot_"),
			//	      "+++\"" + insList[i+2] + " ");
			}
		    }
		} else {
		    helperElt = $(hlpDoc).find("shf")[0].children[2];
		}
    }
    AddHelperHierarchy('right', helperElt);
	    
//	    tclHelpers = $(hlpDoc).find("container");
//	    for (var i=0; i<tclHelpers.length; ++i) {
//		addTabFor(tclHelpers[i].attributes.type.value,
//			  tclHelpers[i].textContent);
//	    }
// resize in case rows of tabs have squeezed panes
//	    resize_notebook();
//	}); // GetXMLHelperSetup
    ResizeAll();
}

function AddHelperHierarchy(win, xml) {
    if (xml == undefined) return;
	switch (xml.nodeName) {
	case "container":
	    if (setupHelperIn(win, xml.attributes.type.value,
			      xml.textContent)) {
		currentHelpers[win] = currentHelper;
	    }
	    break;
	case "panedwindow":
	    var panes = xml.children;
	    if (panes.length == 1) {
		AddHelperHierarchy(win, panes[0].children[0]);
	    } else {
		var splitList = [];
		//buffer = document.createElement("div");
		//buffer.id = win + '_bfr';
		//buffer.style.width = buffer.style.height = '100%';
		//$('#' + win)[0].appendChild(buffer);
		var orient = xml.attributes.orient.value;
		// work around bug
		if (orient == 'horizontal') {
		    axis = 'width';
		} else {
		    axis = 'height';
		}
		var buffer = $('#' + win)[0];
		for (var j=0; j<panes.length; ++j) {
		    if (panes[j].nodeName == "pane") {
			var newChild = document.createElement("div");
			var newId = win + "_pane" + tabCounter++;
			newChild.setAttribute("id", newId);
			// newChild.style.height = '100%';
			newChild.className = "split split-" + orient;
			buffer.appendChild(newChild);
			splitList.push('#' + newId);
			
			AddHelperHierarchy(newId, panes[j].children[0]);
		    }
		}
		
		var adjust = function () {ResizeTree(win)};
		//setTimeout(function () {
		    Split(splitList, {
		    direction: orient,
		    minSize: 200,
		    onDrag: adjust
		    });
		//}, 10);
	    }
	    break;
	case "notebook":
	    winGrp = $('#' + createNotebook(win));
	    if (win == 'right') {
		// top-level notebook, add model diagram tab!
		var newId = new_tab(winGrp, "Model Diagram");
		winGrp.tabs("option", "active", 0);
		insert_helper(newId, "diagram");
		currentHelpers[newId] = currentHelper;
	    }
	    var tabs = xml.children;
	    for (var j=0; j<tabs.length; ++j) {
		var newId = new_tab(winGrp, tabs[j].attributes.caption.value);
		winGrp.tabs("option", "active", j+(win == 'right'));
		AddHelperHierarchy(newId, tabs[j].children[0]);
	    }
	    winGrp.tabs("option", "active", 0);
	    break;
	default:
	    console.log("Unknown XML element type:" + xml.nodeName);
	}
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
    for (i=0;i<tArr.length;++i) {
	Module.ccall('setstep', 'number', ['number', 'number', 'number'],
		     [modelInstance, tArr[i]*unit, i+1]);
    }
}

function js_from_tgts(note) {
    var allResults = {};
    for (var i=0; i<note.length;i++) {
	if (note[i].constructor === Object) {
	    resIndx = JSON.stringify(note[i]);

	    if (note[i].format == "binary") {
		allResults[resIndx] = binary_from_local(note[i].node, note[i].bottom, note[i].top);
	    } else {
		allResults[resIndx] = 'placeholder';
	    }
	} else {
	    resIndx = note[i];
	    allResults[resIndx] = js_from_local_model(resIndx, 1000000);
	}
    }
    return allResults;
}

var resetDepth = -2;
var savedStart = "stop";
function model_reset(ratesOnly) {
    if (!ratesOnly) { // actual reset
	if (savedStart == "run") {
	    savedStart = "stop";
	    return; // exec loop will exit and call this again
	}
	var current = pipeBits.resetTo;
	var depth = resetDepth;
	resetDepth = 0;
    } else {
	current = $("#ct").val();
	var depth = 1;
    }

    note = ofInterest();
    scaleTimes($("#ts").val(),timeUnit);
    var i_result = Module.ccall('reset', 'number',
			['number', 'number', 'number', 'number', 'number'],
			[modelType, modelInstance, 0.0, 0, depth]);

//    $.ajax({
//	type: "POST",
//	url: "model_action.php",
//	data: { "base":fileBase, "act":"Reset",
//		"runlength":$("#rl").val()*timeUnit, "current":current*timeUnit,
//		"step":scaleTimes($("#ts").val(),timeUnit),
//		"method":pipeBits.intMethod, "depth":resetDepth,
//		"note":JSON.stringify(note)}
//    })
//	.done(function( initVals ) {
    if (!ratesOnly) { // actual reset
	    if (isFinite(savedStart)) { // model has been paused before run end
		$("#rl").val(parseFloat($("#rl").val())+parseFloat($("#ct").val())
			     -savedStart);
	    }
	    savedStart = "stop";
	    $("#ct").val(current);
	    $( "#progress" ).progressbar({ value: 0 });
    }
    allResults = js_from_tgts(note);
    update_helpers(current, allResults, ratesOnly);
    if (depth == -2) {
	createInitialHelpers();
    }
}

var TEMPaimToStop;
function model_step(current, start, end, span) {
    if (current >= end || savedStart != "run") {
	// we are done, reset progress bar
	goImage = document.getElementById("button_op");
	goImage.src = "images/play.gif";
	goImage.parentNode.onclick = function () { model_exec(); };
	if (savedStart == "stop") { // reset selected during run
	    savedStart = start;
	    model_reset(0);
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
	log = parseFloat($("#de").val());
	interval = Math.min(end-current,span);
	newCurrent = current+interval;
	newRemain = end-newCurrent;
	setValue(TEMPaimToStop, newCurrent*timeUnit, 'double');

	var intMethod = ['Euler', 'Runge-Kutta'].indexOf(pipeBits.intMethod);
	Module.ccall('execute', 'number',
		     ['number', 'number', 'number', 'number',
		      'number', 'number', 'number', 'number'],
		     [modelType, modelInstance, intMethod, current*timeUnit,
		      TEMPaimToStop, 0, 0, 0]);
	var halted = getValue(TEMPaimToStop, 'double')/timeUnit;
	if (halted+1e-12 < newCurrent) {
	    savedStart = 'pause';
	    console.log("Stopped before", newCurrent, "at", halted);
	}

	// now... we have all the values in memory, but there is a wee overhead
	// converting them to object -- so only do this where of interest...
	note = ofInterest();
	allResults = js_from_tgts(note);
	update_helpers(halted, allResults, true);
	$("#ct").val(halted);
	newProgress = 100*(halted-start)/(end-start);

// now, process the values while fetching the next lot (after timeout in case
// still processing last lot)
	setTimeout(function () {
	    model_step(newCurrent, start, end, span);
	});
    }
    $("#rl").val(newRemain);
    $( "#progress" ).progressbar({
	value: newProgress
    });
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
    span = $("#de").val()
    scaleTimes($("#ts").val(),timeUnit);

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

// actual addTab function: adds new tab using the input from the form above
var helperTitles = {"plot":"Plotter","table":"Data table",
		    "sliders":"Input sliders","params":"File parameters",
		    "shapes":"3-D shape viewer","grid":"Spatial grid",
		    "polys":"Polygon map", "diagram":"Model Diagram"},
tabTemplate = "<li><a href='#{href}'>#{label}</a> <span class='ui-icon ui-icon-close' role='presentation'>Remove Tab</span></li>",
tabCounter = 1;

function new_tab(tabs, label) {
    id = "tabs-" + tabCounter++,
    li = $( tabTemplate.replace( /#\{href\}/g, "#" + id ).replace( /#\{label\}/g, label ) ),
    tabs.find( ".ui-tabs-nav" ).append( li );
    tabs.append( "<div id='" + id + "' style='height:100%'></div>" );
    tabs.tabs( "refresh" );
    return(id);
}

var currentHelpers = {};
var currentHelper = null;
var lastHelper = null;
var lastIndex = null;
function new_helper(type) {
    id = add_tab($('#right_nb'), helperTitles[type]);
    insert_helper(id, type);
    currentHelpers[id] = lastHelper = currentHelper;
}

function add_tab(tabs, title) {
    id = new_tab(tabs, title);
    lastIndex = tabs.children().length - 2;
    tabs.tabs("option", "active", lastIndex);
    return id;
}

function insert_helper(id, type) {
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
    } else if (type == "diagram") {
	currentHelper = new ModelDiagram(id);
    }
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

function ResizeTree(win) {
    console.log('Resizing ' + win);
    if (win == "") return;
    var holder = $('#' + win);
    var leaf = currentHelpers[win];
    if (leaf == undefined) {
	var twigs = holder[0].children;
	for (var i=0; i < twigs.length; ++i) {
	    ResizeTree(twigs[i].id);
	}
    } else {
	leaf.resize(holder.width(), holder.height());
    }
}

//window.onresize = function() {resize_notebook()};
function ResizeAll() {
    for (var win in currentHelpers) {
	holder = $('#' + win);
	currentHelpers[win].resize(holder.width(), holder.height());
    }
}

window.onresize = ResizeAll;

function select_for(helperId, compId) {
    currentHelper = currentHelpers[helperId];
    currentHelper.acceptClick(compId);
}

function select_for_helper(compId) {
  if (currentHelper != null) {
    currentHelper.acceptClick(compId);
  }
}

function toModel(zapTgt, id) {
    sendValue(id, GetSliderValue(zapTgt));
    model_reset(1);
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
//args for poly: this.scaleGrp[0],this.scaleGrp[0],w,this.diagZoom
function mapToScreen(object, eyepiece, w, action) {
    bbox = object[0].getBBox();
    // console.log(JSON.stringify(bbox));
    if (bbox.width==0) return;
    initScale = w/bbox.width;
    action.translate([-initScale*bbox.x,-initScale*bbox.y])
	.scale(initScale);
    grpAttr = "translate("+-initScale*bbox.x+","+-initScale*bbox.y+
	")scale("+initScale+","+initScale+")";
    eyepiece[0].setAttribute("transform",grpAttr);
}


function ModelDiagram (port) {
    this.port = port;

    $('#' + port).html('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" id="' + port + '_diag" viewBox="0 0 800 800" width="800" height="800">  </svg>');
    // above previously included <use xlink:href="#mod_diag" transform="rotate(0)" x="0" y="0" width="800" height="800" />
    document.getElementById(port + '_diag').appendChild(document.getElementById('mod_diag'));
    this.diagZoom = d3.behavior.zoom()
	.on("zoom", function () {
	    d3.select('#' + port + '_diag').select('g') // was 'use'
		.attr("transform", "translate(" + d3.event.translate +
		      ")scale(" + d3.event.scale + ")");
	});
    mapToScreen($('#mod_diag'), $('#' + port + '_diag').children(),
		800, this.diagZoom);
    d3.select('#' + port + '_diag').attr("class","pane").call(this.diagZoom);
}

ModelDiagram.prototype.display = function(time, latest, connect) {
}

ModelDiagram.prototype.resize = function(x, y) {
    $('#' + this.port + '_diag').width(x).height(y);
}

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
  newLine[compId] = js_from_local_model(compId, 1000000);
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
      // If setting up, window may not yet be drawn so redraw after to get dims
      w = 800;
      // w = parseInt(d3.select('#' + this.port).style('width'), 10)-ngap;
      h = 800;
      // h = $('#' + this.port).height()-120;

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
	compId = this.tgts[0]; // to add to yvals after getting data
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
	compId = this.tgts[0]; // to add to yvals after getting data
    }
      totes = this.tgts.length;
      if (this.xval == 'time') {
	  newComps = this.tgts.slice(totes-1,totes);
      } else {
	  newComps = this.tgts.slice(totes-2,totes);
      }
      responses = [];
      for (var i=0; i<newComps.length; ++i) {
	  responses.push(js_from_local_model(newComps[i], 1000000))
      }
		 addys = flatten('t', responses[0]);
		 if (this.xval == 'time') {
// oldys must become an array as maybe more than one var...
		     this.oldys.push(addys);
		 } else {
		     this.oldys = addys;
		     this.oldxs = flatten('t', responses[1]);
		 }

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
    buttonFn = "select_for('" + this.port + "','clear')";
    $('#' + this.port).html("<div id='Buttonbar'><button onclick=" + buttonFn
			    + "><img src='images/new.gif'/></button></div>");
    if (this.vers == 'plot') {
	buttonFn = "select_for('" + this.port + "','add')";
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

      AdjustAxesFor(this, addys);
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
      h = y-144;
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
	units = model_json[bloc.seq].units;
	if (isFinite(units)) {
	    if (units == 1.0) {
	    } else {
		msg += " (x" + units + ")";
	    }
	} else {
	    msg += " (" + units + ")";
	}
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
// 256*16 sweep as gif data
// var legenData = "+gADCBhAoICBAwgSKFjAoIGDBxAiSJhAoYKFCxgyaNjAoYOHDyBCiBhBooSJEyhSqFjBooWLFzBiyJhBo4aNGzhy6NjBo4ePH0CCCBlCpIiRI0iSKFnCpImTJ1CiSJlCpYqVK1iyaNnCpYuXL2DCiBlDpoyZM2jSqFnDpo2bN3DiyJlDp46dO3jy6NnDp4+fP4ACCRpEqJChQ4gSKVrEqJGjR5AiSZpEqZKlS5gyadrEqZOnT6BCiRpFqpSpU6hSqVrFqpWrV7BiyZpFq5atW7hy6drFq5evX8CCCRtGrJixY8iSKVvGrJmzZ9CiSZtGrZq1a9iyadvGrZv6t2/gwokbR66cuXPo0qlbx66du3fw4smbR6+evXv48unbx6+fv3//CESQQQgpxJBDEElEkUUYacSRRyCJRJJJKKnEkkswyUSTTTjpxJNPQAlFlFFIKcWUU1BJRZVVWGnFlVdgiUWWWWipxZZbcMlFl1146cWXX4AJRphhiCnGmGOQSUaZZZhpxplnoIlGmmmoqcaaa7DJRpttuOnGm2/ACUecccgpx5xz0ElHnXXYacedd+CJR5556KnHnnvwyUefffjpx59/AApY0EEJLdTQQxFNVNFFGW3U0UchjVTSSSmt1NJLMc1U00057dTTT0ENVdRRSS3V1FNRTfpV1VVZbdXVV2GNVdZZaa3V1ltxzVXXXXnt1ddfgQ1W2GGJLdbYY5FNVtllmW3W2WehjVbaaamt1tprsc1W22257dbbb8ENV9xxyS3X3HPRTVfdddlt19134Y1X3nnprdfee/HNV999+e3X338BDjRogYYimOiCjDr4aISSUljphZhquGmHnoIY6oikmnhqiqqy2OqLsMo4a4224pjrjrz6+GuQwhJZ7JHIKrlsk85CGe2U1Fp5bZbactntl+CKOW6Z5qKZ7prsuvlunPLSWe+d+Oq5b5/+AhrwgIQaeGiCijLY6IOQSjhphZZimOmGnHr4aYiikljqiaiq+rhqi67CGOuMtNp4a4668tjrj8AKOWyRxiKZ7JLMOvlslNJSWe2V2Gq5bZfeghnumOSaeW6a6rLZ7pvwyjlvnfbime+e/Pr5b6ACE1jogYgquGiDjkIY6YSUWnhphppy2OmHoIo4aommopjqiqy6+GqMstJY64246rhrj74CGeyQxBp5bJLKMtnsk9BKOW2V1mKZ7ZbcevltmOKSWe6Z6Kq5bpvuwhnvnPTaeW+e+vLZ758AE5TrtGYw2XlNYbYTm8N0ZzaJ+U5tFhOe2zRmPLl5THl2E5nz9GYy6flNZdYTnMu0ZziZeU9xNhOf43RmPsn5TH2WE5r7NGdrNPl5Tmn2E53T9Gc6qflPdVYTYNYKFruuJax2YWtY7soWsd6lrWLBa1vGihe3jiWvbiFrXt5KFr2+pax6gWtZ9goXs+4lrmbha1zOyhe5nqWvckFrX+aKFr/OJa1+oWta/koXtf6lrmoACwgAOw==";
// now as bmp
var legenData = "";
for (var r=0; r<16; ++r) {
    for (var c=0; c<256; ++c) {
	legenData += String.fromCharCode(c);
    }
}

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
		data += String.fromCharCode(b, g, r, 0);
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
	    data += String.fromCharCode(c.B, c.G, c.R, 0);
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
    for (j=2;j>=0;--j) {
	s = map.charCodeAt(4*line+j).toString(16);
	if (s.length<2)
	    colSpec = colSpec + "0"; // pad
	colSpec = colSpec + s;
    }

    return colSpec;
}

function BuildBMHeader(depth, width, height) {
    var dataLen = 4*Math.ceil(width/4)*height*depth/8;
    var hdr = depth <= 8 ? 54 + Math.pow(2, depth)*4 : 54;
	       
   //BMP Header
    headerData  = 'BM';                          // ID field
    headerData += conv(hdr + dataLen);     // BMP size
    headerData += conv(0);                       // unused
    headerData += conv(hdr);                  // pixel data offset
  
    //DIB Header
    headerData += conv(40);                      // DIB header length
    headerData += conv(width);                  // image width
    headerData += conv(height);                  // image height
    headerData += String.fromCharCode(1, 0);     // colour panes
    headerData += String.fromCharCode(depth, 0); // bits per pixel
    headerData += conv(0);                       // compression method
    headerData += conv(dataLen);              // size of the raw data
    headerData += conv(2835);                    // horizontal print resolution
    headerData += conv(2835);                    // vertical print resolution
    headerData += conv(0);                       // colour palette, 0 == 2^n
    headerData += conv(0);                       // important colours
    return headerData;
}

Polygon.prototype.acceptClick = function (nodeId) {
    if (this.status == "initializing") {
	this.tgts[0] = nodeId;
	this.status = "getting_x_coords";
	d3.select('#' + this.port + '_instruct').html("Select component with values for X coordinates of verices");
    } else if (this.status == "getting_x_coords") {
	this.xpts = nodeId; // not tgts[1] we lose interest having got them
	this.status = "getting_y_coords";
	d3.select('#' + this.port + '_instruct').html("Select component with values for Y coordinates of verices");
    } else {
/*
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
*/
	headerData = BuildBMHeader(8, 256, 16) + this.cMap;
	
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
    this.legend.src = 'data:image/bm;base64,'
	    + btoa(headerData + legenData);
    this.legend.alt = "Something has gone terrubly winf";

	this.ypts = nodeId;
	this.status = "displaying";
	d3.select('#' + this.port + '_instruct').html("");

	lookAt = [this.tgts[0],this.xpts,this.ypts];
	newTitle = model_json[this.tgts[0]].text + ' -- polygon map';
	$('#tabs a[href=#' + this.port + ']').text(newTitle);
	responses = [];
	for (var i=0; i<lookAt.length;++i) {
	    responses.push(js_from_local_model(lookAt[i], 1000000))
	}
	       colScaler = 255/(this.top-this.bottom); 
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
		   colFract = Math.floor((colours[inds]-this.bottom)*colScaler);

		   // OK now add the poligonnn

		   colSpec = colorFrom(this.cMap, colFract);
		   this.scaleGrp.append("polygon")
		       .attr("id", this.port + niceInds).attr("points",pts)
		       .attr("fill",colSpec).attr("stroke","black")
		       .attr("stroke-width",0);
	       }
	       bbox = this.scaleGrp[0][0].getBBox();
	       // console.log(JSON.stringify(bbox));
	       initScale = 800/bbox.width;
	       this.diagZoom.translate([-initScale*bbox.x,-initScale*bbox.y])
		   .scale(initScale);
	       grpAttr = "translate("+-initScale*bbox.x+","+-initScale*bbox.y+
		   ")scale("+initScale+","+initScale+")";
	       this.scaleGrp.attr("transform",grpAttr);
//	   }); // Query
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
      h = y-100-ngap;
    d3.select('#' + this.port + '_diag').attr("width",w).attr("height",h);

    // problem: getbbox returns 0s if diagram not visible
    // -- so need to either raise any notebook tabs I am
    // in, or do this inline -- works fine if done here!
    if (this.scaleGrp.attr("transform") == null) {
	bbox = this.scaleGrp[0][0].getBBox();
	// console.log(JSON.stringify(bbox));
	if (bbox.width==0) return;
	initScale = w/bbox.width;
	this.diagZoom.translate([-initScale*bbox.x,-initScale*bbox.y])
	    .scale(initScale);
	grpAttr = "translate("+-initScale*bbox.x+","+-initScale*bbox.y+
	    ")scale("+initScale+","+initScale+")";
	this.scaleGrp.attr("transform",grpAttr);
    }
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
      h = y-100-ngap;
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

    responses = js_from_tgts(note);
	       if (this.status == "setting_aspect") {
		   this.width = parseInt(responses[note[0]]);
		   this.height = Math.floor(this.height/this.width);
		   arrInd = 1;
	       } else {
		   arrInd = 0;
	       }
    //BMP Header
    data = BuildBMHeader(8, this.width, this.height) + this.cMap;
	       this.headerBMP = data;

	       this.status = "displaying";
	       d3.select('#' + this.port + '_img')
		   .attr("width",this.width).attr("height",this.height)
		   .attr("xlink:href", 'data:image/bmp;base64,' + btoa(this.headerBMP + responses[JSON.stringify(note[arrInd])]));
	       if (this.hex) {
		   d3.select('#' + this.port + '_img')
		       .attr("transform","scale(1.732,1.5)"); 
	       }

    headerData = BuildBMHeader(8, 256, 16) + this.cMap;
	       //black -> red -> white

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
    this.legend.src = 'data:image/bmp;base64,'
	+ btoa(headerData + legenData);
    this.legend.alt = "Something has gone terrubly winf";
//    resize_notebook();
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
	.attr("xlink:href", 'data:image/bmp;base64,' + btoa(this.headerBMP + arr));
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

var needInput;
function populateStructs() {
  /* NEW SECTION: Get and display metadata from the model */
  /********************************************************/

var nodecount=Module.ccall('get_node_count','number',['number'],[modelType]);
console.log("This model has " + nodecount + " components.");

var name = _malloc(255); // string
var ndims = _malloc(128); // 32 ints
var types = _malloc(256); // 32 ptrs

model_json = {};
var class_strs = ["SUBMODEL", "VARIABLE", "COMPARTMENT", "FLOW", "CONDITION",
		  "CREATION", "REPRODUCTION", "IMMIGRATION", "LOSS", "ALARM",
		  "EVENT", "SQUIRT", "STATE"];
var eval_strs = ["EXOGENOUS", "DERIVED", "TABLE", "INPUT", "GHOST", "LIMIT",
		 "RECALL", "BLOCK", "POPULATION", "GRID", "HONEYCOMB"];
for (ncount=1; ncount<nodecount; ++ncount) {
    var nodedata = Module.ccall('get_data_line', 'number', ['number','number'],
				[modelType, ncount]);
    var nd_name = Module.ccall('name_from_nodlin', 'string', ['number'],
			       [nodedata]);
    var nd_eqn = Module.ccall('eqn_from_nodlin', 'string', ['number'],
			       [nodedata]);
    // console.log("Checking component with id " + nd_name);

    Module.ccall('searchinfo', 'number',
		 ['string', 'number', 'number', 'number', 'number'],
		 [nd_name, modelType, name, ndims, types]);
    var cp = Pointer_stringify(name);
    // console.log("Checking component with caption path " + Pointer_stringify(name));

    // now get parent id...
    var lIO = cp.lastIndexOf('/');
    var pcp = cp.slice(0,lIO);
    var txt = cp.slice(lIO+1);
    if (pcp.length) {
	parentId = Module.ccall('getNodeId', 'string', ['number','string'],
			   [modelType, pcp]);
    } else {
	parentId = '#';
    }
    var dposn = 0;
    var dims = [];
    do {
	dims[dposn] = getValue(ndims+4*dposn, 'i32');
       } while (dims[dposn++]);
    var nd_class = Module.ccall('class_from_nodlin', 'number', ['number'],
			       [nodedata]);
    var type = Module.ccall('type_from_nodlin', 'number', ['number'],
			       [nodedata]);
    var min = Module.ccall('min_from_nodlin', 'number', ['number'],
			       [nodedata]);
    var max = Module.ccall('max_from_nodlin', 'number', ['number'],
			       [nodedata]);
    var evl = Module.ccall('eval_from_nodlin', 'number', ['number'],
			       [nodedata]);
    var us = Module.ccall('units_from_nodlin', 'string', ['number'],
			       [nodedata]);
    model_json[nd_name] = {"parent":parentId,"icon":"images/"
			   + class_strs[nd_class] + ".gif","text":txt,
			   "captpath":cp,"equation":nd_eqn,
			   "min":min, "max":max, "eval":eval_strs[evl],
			   "units":us, "type":type_strs[-type],"dims":dims};
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

	       if ((model_json[id].eval == "INPUT" || 
		    model_json[id].eval == "TABLE") &&
		     model_json[id].type != "VALUELESS") {
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
		  $("#"+data.node.id).prop('title', prettify(js_from_local_model(data.node.id, 1000)));
	      })
	   // create the instance
	      .jstree({ 'core' : {
		   'data' : treeData
	      }
		      });

    needInput = 0; // hopefully
}

var ptBytes;
var ptDims;
function parameterizeContents(smNode, prefix) {
    var sets = smNode.children
    for (var i=0; i<sets.length; ++i) {
	if (sets[i].nodeName == 'variables') {
	    var subsets = sets[i].children;
	    for (var j=0; j<subsets.length; ++j) {
		var pmCapt = prefix+'/'+subsets[j].attributes.label.value;
		if (subsets[j].nodeName == 'single_value') {
		    sendValue(idFromCapt(pmCapt),
			      subsets[j].attributes.val.value);
		} else if (subsets[j].nodeName == 'byte_array') {
		    // results of sending string direct are poor, so...
		    var rawData = atob(subsets[j].textContent);
		    var fpHandle = fvHandles[idFromCapt(pmCapt)];
		    if (subsets[j].children[0].attributes.val.value == "TIME") {
			// time series...try to emulate code in ame_cmx
			var squirtPtr = 0;
			var count = Module.ccall('param_array_size', 'number',
						 ['number'], [fpHandle]);
			while (squirtPtr < rawData.length) {
			    for (var k=0; k<8; ++k) {
				setValue(aligner+k,
					 rawData.charCodeAt(squirtPtr+k), 'i8');
			    }
			    seekTime = getValue(aligner, 'double');
			    // console.log('Loading block for', seekTime);
			    Module.ccall('create_time_point', 'number',
					 ['number', 'number'],
					 [fpHandle, seekTime]);
			    Module.ccall('get_timepoint_ptr_and_dims', 'number',
					 ['number','number','number','number'],
					 [fpHandle, seekTime, ptBytes, ptDims]);
			    var buffer = getValue(ptBytes, '*');
			    squirtPtr += 8;
			    for (var k=0; k<count; ++k) {
				setValue(buffer+k,
					 rawData.charCodeAt(squirtPtr+k), 'i8');
			    }
			    // console.log('Target is', buffer, '1st val',
			    // 		getValue(buffer, 'double')); // or...
			    squirtPtr += count;

			    // extras
			    var time = Module.ccall('get_wrap_ptr', 'number',
						   ['number'], [fpHandle]);
			    setValue(mtd, 0, 'double'); // default no wrap
			    var mtd = Module.ccall('get_fill_ptr', 'number',
						   ['number'], [fpHandle]);
			    setValue(mtd, 0, 'i32'); // default use_last
			    uftsi = subsets[j].attributes.interval.value;
			    if (uftsi == undefined) {
				uftsi = 1;
			    }
			    var time = Module.ccall('get_interval_ptr','number',
						    ['number'], [fpHandle]);
			    setValue(time, timeLib[uftsi], 'double');
			}
			
		    } else {
			var buffer = _malloc(rawData.length);
			for (var k=0; k<rawData.length; ++k) {
			    setValue(buffer+k, rawData.charCodeAt(k), 'i8');
			}
			var zpd = Module.ccall('paste_param_data', 'number',
					   ['number', 'number'],
					   [fpHandle, buffer]);
			_free(buffer);
		    }
		    console.log('Data for', pmCapt, 'at', zpd);
		}
	    }
	} else if (sets[i].nodeName == 'submodels') {
	    var subsets = sets[i].children;
	    for (var j=0; j<subsets.length; ++j) {
		if (subsets[j].nodeName == 'submodel') {
		    parameterizeContents(subsets[j], prefix+'/'+
					 subsets[j].attributes.label.value);
		}
	    }
	}
    }
}

function loadParams() {
    for (i=0;i<fvParms.length;i++) {
	id = fvParms[i];
	input = "#prm_" + id;
	sendValue(id, JSON.parse($(input).val()));
    }
    resetDepth = -1;
    model_reset(0);
}

var currentParamIndices;
function copy_params (bloc, paramDims, nCurInds, remDims, val) {
    if (remDims) {
	var curBound = getValue(paramDims+nCurInds, 'i32');
	for (var i=0; i<curBound; ++i) {
	    setValue(currentParamIndices+nCurInds, i+1, 'i32');
	    copy_params(bloc, paramDims, nCurInds+4, remDims-1, val[i]);
	}
    } else {
	//console.log('Setting: dim1', getValue(paramDims+4, 'i32'), 'ind1',
	//	    getValue(currentParamIndices, 'i32'), 'val', val);
	Module.ccall('set_bloc_element', 'number',
		     ['number', 'number', 'number', 'number'],
		     [bloc, paramDims, currentParamIndices, val]);
    }
}

var pParamDims;
function sendValue(comp, value) {
    //alert(JSON.stringify(parmBlock));
    var dimty = model_json[comp].dims.indexOf(0);
    setValue(currentParamIndices+4*dimty, 0, 'i32'); // terminates indices
    var bloc = Module.ccall('get_param_ptr_and_dims', 'number',
			    ['number', 'number'],
			    [fvHandles[comp], pParamDims]);
    copy_params(bloc, getValue(pParamDims, '*'), 0, dimty, value);
}

// window.onbeforeunload = function(e) {
//   return 'Warning: model state will be lost if you leave the site!';
// };
// window.onunload = function(e) {
//     $.post('model_action.php', { "act":"Exit", "base":fileBase});
// };

function createNotebook(handle) {
    tabHdl = handle + "_nb";
    d3.select('#' + handle).append("div")
	.attr("id", tabHdl)
	.attr("class", "ui-layout-center")
	.style('height','100%')
	.html('<ul></ul>');
    tabs = $('#' + tabHdl);
    tabs.tabs({heightstyle:"fill"});
    tabs.tabs({
	activate: function( event, ui ) {
	    ResizeTree($(ui.newPanel.selector)[0].id);
// 	    if (ui.newPanel.selector != "#tabs-0") { // diagram
// 		lastHelper = currentHelper =
// 		    currentHelpers[$(ui.newPanel.selector)[0].id];
// 		lastIndex = tabs.tabs("option","active");
// 	    } else {
// 		currentHelper = null;
// 	    }
	}
    });
// close icon: removing the tab on click
    tabs.delegate( "span.ui-icon-close", "click", function() {
	var panelId = $( this ).closest( "li" ).remove().attr( "aria-controls" );
	delete currentHelpers[panelId];
	$( "#" + panelId ).remove();
	tabs.tabs( "refresh" );
    });
    return tabHdl;
}

var pipeBits;

// functions for interacting with local emscripten model

// extras
function MakeSubBlockSizes (dims) {
    var usedDims = 1;
    var dim0 = getValue(dims, 'i32');
    msbs_dims.push(dim0);
    var tName = type_strs[-dim0];
    if (dim0 < -5) { // enumerated type etc
	tName = "INTEGER";
    }
    if (tName != undefined) {
	sizes = [];
	switch (tName) {
	case "SPARSEARRAY":
	    msbs_dims.push(getValue(dims+4, 'i32')); // transcribe index count
	    usedDims = 2; // and fall through
	case "OWNSIZED":
	    sizes = MakeSubBlockSizes(dims+4*usedDims);
	    size = 8; // sizeof(sizeAndPtr);
	    break;
	case "REAL":
	    size = 8; // sizeof(double);
	    break;
	case "INTEGER":
	    size = 4; // sizeof(int);
	    break;
	case "FLAG":
	    size = 1; // sizeof(BOOLEAN);
	    break;
	case "VALUELESS":
	    size = 0;
	    break;
	}
    } else { // dimension
	sizes = MakeSubBlockSizes(dims+4);
	size = sizes[0] * dim0;
    }
    sizes.splice(0,0,size);
    return sizes;
}

var aligner; // aligned place
function brutally_align(ragged) {
    // will probably have to do something like below for all, since
    // booleans can cause odd alignment
    setValue(aligner, getValue(ragged, 'i32'), 'i32');
    setValue(aligner+4, getValue(ragged+4, 'i32'), 'i32');
}

function convert_to_js(dims, subBlocks, blob, count) {
    var localObj;
    var newBlob;
    if (dims[0] > 0) { // it's an array bound
	localObj = append_array_members(dims[0], dims.slice(1),
					subBlocks.slice(1), blob, count);
    } else {
	switch (type_strs[-dims[0]]) {
	case "OWNSIZED":
	    membership = Module.ccall('size_from_sznptr', 'number',
				      ['number'], [blob]);
	    newBlob = Module.ccall('ptr_from_sznptr', 'number',
				      ['number'], [blob]);
	    localObj = append_array_members(membership, dims.slice(1),
					    subBlocks.slice(1), newBlob, count);
	    break;
	case "SPARSEARRAY": 
	    // need clevers to nest indices; see old stuff
	    membership = Module.ccall('size_from_sznptr', 'number',
				      ['number'], [blob]);
	    newBlob = Module.ccall('ptr_from_sznptr', 'number',
				      ['number'], [blob]); // done
	    indices = [];
	    if (count[0]<0) { // start at last index group and work back
		newBlob = newBlob+(membership-1)*(dims[1]*4+subBlocks[1]);
	    }
	    pMemBlb = {'mem':membership, 'blb':newBlob};
// console.log("oblb", blob, JSON.stringify(pMemBlb), "vm dims", dims[1]);
	    localObj = append_list_members(dims[1], 0, dims.slice(2), indices,
					   subBlocks.slice(1), pMemBlb, count);
	    break;
	case "VALUELESS":
	    localObj = 'sm';
	    count[0] -= count[0]>0?1:-1;
	    break;
	case "REAL":
	    brutally_align(blob);
	    localObj = getValue(aligner, 'double');
	    count[0] -= count[0]>0?1:-1;
	    break;
	case "FLAG":
	    localObj = getValue(blob, 'i8');
	    count[0] -= count[0]>0?1:-1;
	    break;
	default: /* INTEGER or ENUM(*) */
	    localObj = getValue(blob, 'i32');
	    count[0] -= count[0]>0?1:-1;
	    break;
	}
    }
    return localObj;
}

function append_list_members(dimty, depth, dims, indices, 
			     subBlocks, pMemBlb, toGet) {
  var localObj;

  dir = toGet[0]>0?1:-1;
  if (depth==dimty) {
    if (pMemBlb.mem) {
      pMemBlb.blb += dimty*4;
      localObj = convert_to_js(dims, subBlocks, pMemBlb.blb, toGet);
      if (dir>0) {
	  pMemBlb.blb += subBlocks[0];
      } else {
	  pMemBlb.blb -= (subBlocks[0]+2*dimty*4);
      }
      --pMemBlb.mem;
    } else {
	localObj = {};
    }
  } else {
      localObj = {};
      while (pMemBlb.mem && toGet[0]) {
	  for (count=0; count<depth; ++count) {
	      if (getValue(pMemBlb.blb+4*count,'i32')!=indices[count])
		  return(localObj);
	  }
	  indices[depth] = getValue(pMemBlb.blb+4*depth,'i32');
	  var localSubObj = append_list_members(dimty, depth+1, dims, indices,
						subBlocks, pMemBlb, toGet);
	  if (localSubObj != {}) {
	      localObj[indices[depth].toString()] = localSubObj;
	  }
      }
  }
  return(localObj);
}

function append_array_members(membership, dims, subBlocks, blob, count) {
    var start, end, localObj = {};
    var dir = count[0]>0?1:-1;
    if (dir==1) {
	start = 1; end = membership+1;
    } else {
	start = membership; end = 0;
    }

    for (var offset = start; offset != end; offset += dir) {
	if (!count[0]) break;
	var localSubObj = convert_to_js(dims, subBlocks,
					blob+(offset-1)*subBlocks[0], count);
	if (localSubObj != {})
	    localObj[offset.toString()] = localSubObj;

    }
    return localObj;
}
// callbacks
function respond_to_param_req(modelId, modelSlot, paramId, indCount, indices) {
    console.log("Parameter value requested: id", paramId,
		indCount, "ind(ex/ices), first is", getValue(indices, "i32"));
    // Copy the appropriate value over from the array
    setValue(modelSlot,
	     myParams[getValue(indices, "i32")][getValue(indices+4, "i32")],
	     'double');
}

function show_a_message(message) {
    console.log("message from dll:", Pointer_stringify(message));
}

function show_model_time(spare, spare2, model_time) {
    console.log("model time:", model_time);
    return 0; // 1 if GUI stops model execution
}

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

var type_strs = ["VALUELESS", "REAL", "INTEGER", "FLAG",
		 "OWNSIZED", "SPARSEARRAY"];
var modelInstance;
var fvHandles;
var timeLib = {"second":1/86400,"minute":1/1440,"hour":1/24,"day":1,
	       "unit":1,"week":7,"month":365/12,"year":365};
var working = 0;
function prepare() {
    // set up splits
    Split(['#Left', '#right'], {
	sizes: [25, 75],
	minSize: 250,
	onDragEnd: ResizeAll
    });

    Split(['#topleft', '#explorer'], {
	direction: 'vertical',
	sizes: [25, 75],
	minSize: 200
    })

    // display the loading, please wait screen
    $( "#WaitDialog" ).dialog({
	autoOpen: true,
	width: 400,
	modal: true,
    });
    // remove the title bar
    $(".ui-dialog-titlebar").hide();


    // See if we can inject the executable asm.js at this point...
    $.ajax({
	type: "POST",
	url: 'model_action.php',
	data: {"act":"GetAsmJs", "base":fileBase},
	dataType: 'script'})
	.done(function(execParms) {
	    TEMPaimToStop = _malloc(8); // a double
	    ptBytes = _malloc(8);
	    ptDims = _malloc(8);
	    currentParamIndices = _malloc(128); // 32 * int
	    pParamDims = _malloc(8); // int*
	    aligner = _malloc(8); // aligned place
  /* start by loading the dll with the constants and procedures it needs
   from the client */
	    Module.ccall('proc_pointers_for_shank', 'number',
			 ['number','number','number'],
			 [Runtime.addFunction(respond_to_param_req),
			  Runtime.addFunction(show_model_time),
			  Runtime.addFunction(show_a_message)]);

// Make space for model class ptr, and fill it
var pmodelType = _malloc(8); // a ptr
var complaint=Module.ccall('load_model', 'string', ['string','string','number'], ['./dummy.so','evaluation',pmodelType]);
modelType = getValue(pmodelType,'*');

if (complaint.length) {
    console.log("Problem creating type: " + complaint);
} else {
    console.log("Created model type OK");
}
    
    // Now stick the values in the run control
    $("#rl").val(pipeBits.execTime);
    $("#de").val(pipeBits.displayInt);
    $("#ts").val(pipeBits.phaseList);
    
    $(".unit").html(pipeBits.timeUnit);
    timeUnit = timeLib[pipeBits.timeUnit];
    
    populateStructs();
    
// now make an instance of the model -- this creates its variables...
modelInstance = _malloc(8); // a ptr

modelInstance = Module.ccall('fetch_top_instance', 'number',
				 ['number', 'number'],
				 [modelType, 20150909]);

if (modelInstance) {
    console.log("Created model instance OK");
} else {
    console.log("Problem creating instance");
}

    // Now we need to set up the file parameter data, if
    // any...later. But we must declare the parameters internal, or it
    // will try to execute a callback function, something that appears
    // not to be working at the moment...
    fvHandles = {};
    for (i=0;i<fvParms.length;i++) {
	fvHandles[fvParms[i]] = Module.ccall('use_array_for_params', 'number',
					     ['number', 'string'],
					     [modelInstance, fvParms[i]]);
    }
    
    // new parameter reader
    if (typeof(paramXML) != 'undefined') {
	pparser = new DOMParser();
	paramNode = pparser.parseFromString(paramXML, 'text/xml');
	parameterizeContents(paramNode.firstElementChild.firstElementChild, '');
    }

    /* initialize it: last arg -2 means set all values, -1 means keep constants,
     0 means keep constants and fixed parameters,
     +ve values mean keep all the above plus state variables */
  
	   $.ajax({
	       type: "POST",
	       url: "model_action.php",
	       data: {"act" : "GetSVG",  "base" : fileBase}
	   })
	       .done (function(diagSVG) {
		   svgDoc = document.createElement("div");
		   svgDoc.innerHTML = diagSVG;
		   document.firstChild.appendChild(svgDoc);
		   // stick it where the sun don't shine
		   
    ModDiag = document.getElementById("mod_diag");
      diag_zoom = d3.behavior.zoom()
	  .on("zoom", function () {
	       d3.select('#mod_diag').select('g')
		  .attr("transform", "translate(" + d3.event.translate +
			")scale(" + d3.event.scale + ")");
	  });
      // d3.select('#mod_diag').attr("class","pane").call(diag_zoom);
      // resize_notebook();
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

    if (needInput) {
	new_helper("params");
	// resets model when params are loaded
    } else {
	model_reset(0);
    }
	    // finally we are ready to roll, wait is over
	    $("#WaitDialog").dialog("close");
	       }); // GetSVG
	}); // GetAsmJs
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
