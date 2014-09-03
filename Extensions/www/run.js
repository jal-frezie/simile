var tabs;
	$(function() {
		

		

		
		$( "#button" ).button();
		$( "#radioset" ).buttonset();
		

		

tabs = $( "#tabs" ).tabs();
		
// close icon: removing the tab on click
tabs.delegate( "span.ui-icon-close", "click", function() {
  var panelId = $( this ).closest( "li" ).remove().attr( "aria-controls" );
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

  var actionX = uupos.x + 10;
  var actionY = uupos.y + 10;
  tooltip_grp.setAttributeNS(null,"transform",
		     "translate(" + actionX + "," + actionY + ")");
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

function SvgDiagZoom(factor) {
  ModDiag.setAttribute("width",factor*ModDiag.getAttribute("width"));
  ModDiag.setAttribute("height",factor*ModDiag.getAttribute("height"));
}

var resetDepth = -2, savedStart;
function model_reset() {
$.ajax({
  type: "POST",
  url: "model_action.php",
  data: { "port" : svrPort, "act": "Reset", "runlength":$("#rl").val(), 
	  "current":0, "step":$("#ts").val(), "note":resetDepth}
})
  .done(function( feedback ) {
    if (feedback != '1') {
      alert(feedback);
      return;
    }
    resetDepth = 0;
    if (savedStart != null) {
      $("#rl").val(parseFloat($("#rl").val())+parseFloat($("#ct").val())
		     -savedStart);
    }
    $("#ct").val(0);
    $( "#progress" ).progressbar({ value: 0 });
    $.post('model_action.php', { "port" : svrPort, "act":"Report"}, 
	   function(data) {
	       values_json = JSON.parse(data);
               update_helpers(0, values_json);
	   });
  });
}

function model_step(current, start, end, span, note) {
  if (current >= end || savedStart != null) {
// we are done, reset progress bar and update values
    $.post('model_action.php', { "port" : svrPort, "act":"Report"}, 
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
    $.ajax({
      type: "POST",
      url: "model_action.php",
      data: {"port":svrPort,  "act":"ExecuteMulti", "runlength":interval, 
	     "current":current, "step":$("#ts").val(), "log":log, "note":note}
    })
      .done(function(newVals) {
	block = JSON.parse(newVals);
        for (var timePt in block) {
          update_helpers(timePt, block[timePt]);
	}
        model_step(newCurrent, start, end, span, note);
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
//  calibrate_helpers(end);
  model_step(now, start, end, 10, ofInterest());
}

function ofInterest() {
// list the paths of all the nodes currently being displayed by tools
  result = [];
  for (i=0; i<currentHelpers.length; i++) {
    if (currentHelpers[i].status == "displaying") {
      for (j=0; j<currentHelpers[i].tgts.length; j++) {
        result[currentHelpers[i].tgts[j]] = 1;
      }
    }
  }
  return Object.getOwnPropertyNames(result).join();
}

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

// actual addTab function: adds new tab using the input from the form above
var helperTitles = {"plot":"Plotter","table":"Data table","sliders":"Input sliders","params":"File parameters"},
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

var currentHelpers = [];
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
  } else {
    currentHelper = new PlotValAgainstTime(id);
  }
  currentHelpers.push(currentHelper);
  tabs.tabs("option", "active", tabs.children().length - 2);
}

function update_helpers(time, latest) {
  for (i=0; i<currentHelpers.length; i++) {
    currentHelpers[i].display(time, latest);
  }
}

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
	input.setAttribute("min", min);
	input.insertAdjacentHTML('afterend', max);
	input.setAttribute("max", max);
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
    document.getElementById(entry).value = zapTgt.value;
}

function toModel(zapTgt, id) {
    parmBlock = {};
    parmBlock[model_json[id].captpath] = 'NOW ' + zapTgt.value;
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

Sliders.prototype.display = function  (time, latest) {
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

FileParams.prototype.display = function  (time, latest) {
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
  $('#' + port).html("<div id='buttonbar'>\
<button type='button' onclick='currentHelper = " + this + "'>Tabulate</button>\
</div>\
<table id='" + this.port + "_table'></table>");
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
  this.t = $('#' + this.port + "_table").dataTable({"data":this.cumData,
				       "columns":this.columns});
}

DataTable.prototype.display = function(time, latest) {
  if (time in this.timeRowIds) {
    newLine = this.cumData[this.timeRowIds[time]];
  } else {
    this.timeRowIds[time] = this.cumData.length;
    newLine = {"time":time};
    this.cumData.push(newLine);
  }
  for (i=0;i<this.tgts.length;i++) {
    toZap = this.tgts[i];
    newLine[toZap] = latest[toZap]
  }
  this.t = $('#' + this.port + "_table").dataTable({"data":this.cumData,
				       "columns":this.columns,
				       "destroy":true});
  this.t.api().page.jumpToData( time, 0 );
}

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

function populateStructs() {
// OK, now use AJAX to get a string of values

$.post('model_action.php', { "port" : svrPort, "act":"Describe"}, 
      function(data) {

	   model_json = JSON.parse(data);

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
	   if (needInput) {
	      new_helper("params");
	   }
      });

// should not do if there are unset parameters
model_reset();
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
      data: { "port" : svrPort, "act":"Parameterize", 
	      "data" : JSON.stringify(parmBlock)}
    })
      .done(function(retsStr) {
	  rets = JSON.parse(retsStr);
          if (rets) {
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
    $.post('model_action.php', { "port" : svrPort, "act":"Exit", 
				 "base":fileBase});
};
// Start the socket -- fttb just hope it is ready when prepare is called
var svrPort = 99999;
$.post('model_action.php', {"act":"CreateSocket", "base":fileBase},
            function() {
               alert("Guess what -- the model exec process just finished");
});

$.post('model_action.php', {"act":"WaitSocket", "base":fileBase}, 
            function(port) {
            	svrPort = port;
                alert("Got socket " + port);
            	populateStructs();
});

////////////////////////////////////// PREPARE /////////////////////////////
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
function prepare() {
$.ajax({
  type: "POST",
  url: "model_action.php",
  data: {"act" : "GetSVG",  "base" : fileBase}
})
  .done (function(diagSVG) {
    document.getElementById("holds_svg").innerHTML = diagSVG;
  
    ModDiag = document.getElementById("mod_diag");
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
  tooltip_grp = document.createElementNS('http://www.w3.org/2000/svg','g');
  tooltip_bd = document.createElementNS('http://www.w3.org/2000/svg','rect');
  tooltip_bd.setAttribute("x", "0");
  tooltip_bd.setAttribute("y", "0");
  tooltip_bd.setAttribute("width", "24");
  tooltip_bd.setAttribute("height", "24");
  tooltip_bd.setAttribute("visibility", "hidden");
  tooltip_bd.style.fill="none";
  tooltip_bd.style.stroke="black";
  tooltip_grp.appendChild(tooltip_bd);
  
  tooltip_qbg = document.createElementNS('http://www.w3.org/2000/svg','rect');
  tooltip_qbg.setAttribute("x", "0");
  tooltip_qbg.setAttribute("y", "0");
  tooltip_qbg.setAttribute("width", "24");
  tooltip_qbg.setAttribute("height", "12");
  tooltip_qbg.setAttribute("visibility", "hidden");
  tooltip_qbg.style.fill="#e0ffe0";
  tooltip_qbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_qbg);
  
  tooltip_vbg = document.createElementNS('http://www.w3.org/2000/svg','rect');
  tooltip_vbg.setAttribute("x", "0");
  tooltip_vbg.setAttribute("y", "12");
  tooltip_vbg.setAttribute("width", "24");
  tooltip_vbg.setAttribute("height", "12");
  tooltip_vbg.setAttribute("visibility", "hidden");
  tooltip_vbg.style.fill="#ffffe0";
  tooltip_vbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_vbg);
  
  tooltip_q = document.createElementNS("http://www.w3.org/2000/svg", 'text');
  tooltip_q.setAttribute("x","4");
  tooltip_q.setAttribute("y","0.8em");
  tooltip_q.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_q.setAttribute("visibility", "hidden");
  tooltip_q.appendChild(document.createTextNode(0));
  tooltip_grp.appendChild(tooltip_q);
  
  tooltip_v = document.createElementNS("http://www.w3.org/2000/svg", 'text');
  tooltip_v.setAttribute("x","4");
  tooltip_v.setAttribute("y","1.8em");
  tooltip_v.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_v.setAttribute("visibility", "hidden");
  var textNode_v = document.createTextNode(0);
  tooltip_v.appendChild(textNode_v);
  tooltip_grp.appendChild(tooltip_v);
  
}
