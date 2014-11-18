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
	       latest = {}
	       oi = ofInterest();
	       for (var i in oi) {
		   latest[oi[i]] = JSON.parse(values_json[oi[i]]);
	       }
               update_helpers(0, latest);
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
//	  alert('Data returned ' + newVals);
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
  model_step(now, start, end, 10, ofInterest().join());
}

function ofInterest() {
// list the ids of all the nodes currently being displayed by tools
  result = [];
  for (i=0; i<currentHelpers.length; i++) {
    if (currentHelpers[i].status == "displaying") {
      for (j=0; j<currentHelpers[i].tgts.length; j++) {
        result[currentHelpers[i].tgts[j]] = 1;
      }
    }
  }
//  return Object.getOwnPropertyNames(result);
// includes "length" which we don't want
  rList = [];
  for (var slot in result) {
      rList.push(slot);
  }
  return rList;
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
    currentHelper = new PlotXY(id);
  }
  currentHelpers.push(currentHelper);
  tabs.tabs("option", "active", tabs.children().length - 2);
}

function update_helpers(time, latest) {
    for (var i=0; i<currentHelpers.length; ++i) {
//	try {
	    currentHelpers[i].display(time, latest);
//	}
//	catch(err) {
//	    console.log(err);
//	}
    }
}

window.onresize = function() {
//    console.log('Window resized');
    for (var i=0; i<currentHelpers.length; ++i) {
	try {
	    currentHelpers[i].resize();
	}
	catch(err) {
	    console.log(err);
	}
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
<button type='button' onclick='currentHelper = currentHelpers[" + currentHelpers.length + "]'>Tabulate</button>\
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
				       "columns":this.columns,
        "scrollY": "800px",
        "scrollCollapse": true,
        "paging": false,
        "jQueryUI": true});
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
    newLine[toZap] = JSON.stringify(latest[toZap])
  }
  this.t = $('#' + this.port + "_table").dataTable({"data":this.cumData,
				       "columns":this.columns,
				       "destroy":true,
        "scrollY": "800px",
        "scrollCollapse": true,
        "paging": false,
        "jQueryUI": true});
//  this.t.api().page.jumpToData( time, 0 );
// above selects page with data, but we want to scroll to it
    var newRow = this.timeRowIds[time];
    var scroller = this.t.fnSettings().nTable.parentNode;
    var rowObj = this.t.api().row(newRow).node();
    $(scroller).scrollTo(rowObj,1);
// sorted -- next, make the bloody thing change size
}

DataTable.prototype.resize = function() {
//    this.t.dataTable({"scrollY": parseInt(d3.select('#tabs').style('height'), 10)-120});
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

function PlotXY (port) {
  this.port = port;
  this.tgts = [];
  this.status = "initializing";

// OK now add the message to the new tab
  $('#' + port).html("Click on a component to plot on the Y axis.");
}

var xyGlbsForD3 = {};
PlotXY.prototype.acceptClick = function (compId) {
  if (this.status == "initializing") {
    this.tgts[0] = compId;
    this.oldys = flatten('t', JSON.parse(values_json[compId]));
    buttonFn = "select_for_helper('time')";
    $('#' + this.port).html("Click on a component to plot on the X axis, or <button type='button' onclick=" + buttonFn + ">here</button> to plot against time.");
    this.status = "getting_x";
  } else {
      this.status = "displaying";
      
      ngap = 40;
//      w = 800;
      w = parseInt(d3.select('#' + this.port).style('width'), 10)-ngap;
//      h = 800;
      h = parseInt(d3.select('#tabs').style('height'), 10)-120;

    if (compId == "time") {
	this.oldt = parseFloat($("#ct").val());
	this.xmin = this.oldt;
	this.xmax = this.oldt + parseFloat($("#rl").val());
	xAxisName = "time";
    } else {
	this.tgts[1] = compId;
	this.oldxs = flatten('t', JSON.parse(values_json[compId]));
	xAxisName = model_json[compId].captpath;
    }
      for (var hdl in this.oldys) {
	if (compId != "time") {
	    if (this.xmin == undefined || this.oldxs[hdl] < this.xmin) {
		this.xmin = this.oldxs[hdl];
            }
	    if (this.xmax == undefined || this.oldxs[hdl] > this.xmax) {
		this.xmax = this.oldxs[hdl];
	    }
	}
	if (this.ymin == undefined || this.oldys[hdl] < this.ymin) {
	    this.ymin = this.oldys[hdl];
        }
	if (this.ymax == undefined || this.oldys[hdl] > this.ymax) {
	    this.ymax = this.oldys[hdl];
	}
    }
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
//    $('#' + this.port).html("Plot of " + model_json[this.tgts[0]].captpath +
//			   " against " + xAxisName);
    $('#' + this.port).html("");
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
      this.lzx = zoomxaxis;
      this.lzy = zoomyaxis;
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

PlotXY.prototype.resize = function() {
   if (this.status != "displaying") return;
//   console.log('Tab width: ' + d3.select('#' + this.port).style('width'));
//   console.log('Notebook height: ' + d3.select('#tabs').style('height'));
    ngap = 40;
//      w = 800;
      w = parseInt(d3.select('#' + this.port).style('width'), 10)-ngap;
//      h = 800;
      h = parseInt(d3.select('#tabs').style('height'), 10)-120;
    this.lx.range([ngap, w+ngap]);
    this.ly.range([0, h]);
    this.lxAxis.tickSize(-h);
    this.lyAxis.tickSize(-w);
    d3.select('#' + this.port + "_xbar")
	.attr("transform", "translate(0," + h + ")");
    this.svg.attr("width",w+ngap).attr("height",h+ngap);
    this.zfn();
}

PlotXY.prototype.display = function (time, latest) {
  if (this.status == "displaying") {
// OK now how big is it? 
      idxs = [];
      newys = flatten('t', latest[this.tgts[0]]);
// console.log(" data is " + JSON.stringify(latest[this.tgts[0]]) + " flat " + JSON.stringify(newys));
      if (this.tgts[1] != undefined) {
	  newxs = flatten('t', latest[this.tgts[1]]);
	  for (var hdl in newys) {
	      idxs.push([{"y":this.oldys[hdl],"x":this.oldxs[hdl]},
			 {"y":newys[hdl],"x":newxs[hdl]}]);
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
	  this.oldxs = newxs;
      } else {
	  for (var hdl in newys) {
	      idxs.push([{"y":this.oldys[hdl],"x":this.oldt},
			 {"y":newys[hdl],"x":time}]);
	      oldymin = this.ymin;
	      if (this.ymin == undefined) {
		  this.ymin = this.ymax = newys[hdl];
	      } else {
		  this.ymin = Math.min(this.ymin,newys[hdl]);
		  this.ymax = Math.max(this.ymax,newys[hdl]);
	      }
// console.log("ymin was " + oldymin + " checked " + newys[hdl] + " is " + this.ymin);
	  }
	  this.oldt = time;
	  if (time>this.xmax) {
	      this.xmax = parseFloat($("#ct").val()) + parseFloat($("#rl").val());
//	      console.log("Boring x range out to " + this.xmax);
// now I need to redraw
	  }
      }
      newGrp = this.svg.append("g")
          .attr("class", "step"); // new group for this time step's data
      newGrp.selectAll(".line") // selects empty set?
	  .data(idxs)
	  .enter().append("path")
	  .attr("class", "trace")
	  .style("stroke","blue")
	  .attr("d", this.line);
      this.oldys = newys;

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
// This will ultimately load the parameter file (if there is one) and
// get a list of components that still need values, or have bad values,
// for flagging in the parameter dialogue
	  $.post('model_action.php', { "port" : svrPort, "act":"LoadSPF", 
				       "base" : fileBase}, 
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
            function(port) {
//               alert("Guess what -- the model exec process just finished");
            	svrPort = port;
                console.log("Got socket " + port);
            	populateStructs();
});

//$.post('model_action.php', {"act":"WaitSocket", "base":fileBase}, 
//            function(port) {
//            	svrPort = port;
//                alert("Got socket " + port);
//            	populateStructs();
//});

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
  tooltip_grp = document.createElementNS(xmlns,'g');
  tooltip_bd = document.createElementNS(xmlns,'rect');
  tooltip_bd.setAttribute("x", "0");
  tooltip_bd.setAttribute("y", "0");
  tooltip_bd.setAttribute("width", "24");
  tooltip_bd.setAttribute("height", "24");
  tooltip_bd.setAttribute("visibility", "hidden");
  tooltip_bd.style.fill="none";
  tooltip_bd.style.stroke="black";
  tooltip_grp.appendChild(tooltip_bd);
  
  tooltip_qbg = document.createElementNS(xmlns,'rect');
  tooltip_qbg.setAttribute("x", "0");
  tooltip_qbg.setAttribute("y", "0");
  tooltip_qbg.setAttribute("width", "24");
  tooltip_qbg.setAttribute("height", "12");
  tooltip_qbg.setAttribute("visibility", "hidden");
  tooltip_qbg.style.fill="#e0ffe0";
  tooltip_qbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_qbg);
  
  tooltip_vbg = document.createElementNS(xmlns,'rect');
  tooltip_vbg.setAttribute("x", "0");
  tooltip_vbg.setAttribute("y", "12");
  tooltip_vbg.setAttribute("width", "24");
  tooltip_vbg.setAttribute("height", "12");
  tooltip_vbg.setAttribute("visibility", "hidden");
  tooltip_vbg.style.fill="#ffffe0";
  tooltip_vbg.style.stroke="none";
  tooltip_grp.appendChild(tooltip_vbg);
  
  tooltip_q = document.createElementNS(xmlns, 'text');
  tooltip_q.setAttribute("x","4");
  tooltip_q.setAttribute("y","0.8em");
  tooltip_q.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_q.setAttribute("visibility", "hidden");
  tooltip_q.appendChild(document.createTextNode(0));
  tooltip_grp.appendChild(tooltip_q);
  
  tooltip_v = document.createElementNS(xmlns, 'text');
  tooltip_v.setAttribute("x","4");
  tooltip_v.setAttribute("y","1.8em");
  tooltip_v.setAttribute("style","font-family: Helvetica; font-size: 9pt;");
  tooltip_v.setAttribute("visibility", "hidden");
  var textNode_v = document.createTextNode(0);
  tooltip_v.appendChild(textNode_v);
  tooltip_grp.appendChild(tooltip_v);
  
}
