<html>
<head>
<title>Running the model</title>
<link rel="stylesheet" href="dist/themes/default/style.css" />
<link href="css/humanity/jquery-ui-1.10.4.custom.css" rel="stylesheet" />
<link href="css/xcharts.min.css" rel="stylesheet" />
<script src="js/jquery-1.10.2.js"></script>
<script src="js/jquery-ui-1.10.4.custom.js"></script>
<script src="dist/jstree.min.js"></script>
<script src="http://d3js.org/d3.v3.min.js" charset="utf-8"></script>
<script src="js/xcharts.min.js"></script>
<style>
#tabs li .ui-icon-close { float: left; margin: 0.4em 0.2em 0 0; cursor: pointer; }
</style>
</head>
<body onload="prepare()">
<?php
session_start();
include_once "model_action.php";

if (isset($_POST['param'])) {
   foreach ($_SESSION['modelParams'] as $parmLine) {
      doTcl("SetParamArrayFromList [set aH($parmLine)] $_POST[$parmLine]");
   }
}

if (isset($_SESSION['runlength'])) {
   $runlength = $_SESSION['runlength'];
   $current = $_SESSION['current'];
   $logstep = $_SESSION['logstep'];
   $step = $_SESSION['step'];
} else {
   $runlength = 100;
   $current = 0;
   $logstep = 1;
   $step = 0.1;

   $line1 = doTcl("join [set catalog] .");
   $_SESSION['paths'] = explode(".", $line1);
				     
// initialize the model, including default slider values
   doTcl("ResetModel [set iH] 0 Euler -2");
}

$_SESSION['runlength'] = $runlength;
$_SESSION['current'] = $current;
$_SESSION['logstep'] = $logstep;
$_SESSION['step'] = $step;

$arrlength=count($_SESSION['paths']);
//echo "<br>Model has " . $arrlength . " components. Form is " . $_POST[step]
//				     . "\n";
// First put up the svg -- insert the code so I can modify it later
?>
<script>
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

var tooltip_grp;
var tooltip_bd;
var tooltip_qbg;
var tooltip_vbg;
var tooltip_q;
var tooltip_v;
var ModDiag;
var values_json;
function prepare() {
  ModDiag = document.getElementById("mod_diag");
  
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
  ModDiag.appendChild(tooltip_grp);
  
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

// OK, now use AJAX to get a string of values

$.get('report.php', function(data) {
    values_json = JSON.parse(data);
});
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
  tooltip_v.firstChild.data = values_json[prolog];
// above will break function if it doesn't work

        var uupos = ModDiag.createSVGPoint();
        uupos.x = evt.pageX;
        uupos.y = evt.pageY;
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

var savedStart;
function model_reset() {
$.ajax({
  type: "POST",
  url: "model_exec.php",
  data: { "act": "Reset", "runlength":$("#rl").val(), "current":$("#ct").val(),
		     "step":$("#ts").val() }
})
  .done(function( newTime ) {
    if (savedStart != null) {
      $("#rl").val(parseFloat($("#rl").val())+parseFloat($("#ct").val())
		     -savedStart);
    }
    $("#ct").val(newTime);
    $( "#progress" ).progressbar({ value: 0 });
    $.get('report.php', function(data) {
		     values_json = JSON.parse(data);
		     });
  });
}

function model_step(current, start, end) {
  if (current >= end || savedStart != null) {
// we are done, reset progress bar and update values
    $.get('report.php', function(data) {
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
    interval = Math.min(end-current,parseFloat($("#le").val()));
    newCurrent = current+interval;
    newRemain = end-newCurrent;
    $.ajax({
      type: "POST",
      url: "model_exec.php",
      data: { "act": "Execute", "runlength":interval, "current":current,
		     "step":$("#ts").val() }
    })
      .done(function() {
         model_step(newCurrent, start, end);
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
  model_step(now, start, now+parseFloat($("#rl").val()));
}

// placeholder graph plot

var pgplot_data = {
  "xScale": "time",
  "yScale": "linear",
  "type": "line",
  "main": [
    {
      "className": ".pizza",
      "data": [
        {
          "x": "2012-11-05",
          "y": 1
        },
        {
          "x": "2012-11-06",
          "y": 6
        },
        {
          "x": "2012-11-07",
          "y": 13
        },
        {
          "x": "2012-11-08",
          "y": -3
        },
        {
          "x": "2012-11-09",
          "y": -4
        },
        {
          "x": "2012-11-10",
          "y": 9
        },
        {
          "x": "2012-11-11",
          "y": 6
        }
      ]
    }
  ]
};
var pgplot_opts = {
  "dataFormatX": function (x) { return d3.time.format('%Y-%m-%d').parse(x); },
  "tickFormatX": function (x) { return d3.time.format('%A')(x); }
};

// actual addTab function: adds new tab using the input from the form above
var helperTitles = {"plot":"Plotter","table":"Data table"},
  tabTemplate = "<li><a href='#{href}'>#{label}</a> <span class='ui-icon ui-icon-close' role='presentation'>Remove Tab</span></li>",
  tabCounter = 2;

function new_helper(type) {
  var label = helperTitles[type];
  id = "tabs-" + tabCounter++,
  li = $( tabTemplate.replace( /#\{href\}/g, "#" + id ).replace( /#\{label\}/g, label ) ),
  tabContentHtml = "Tab contents -- testing";
  tabs.find( ".ui-tabs-nav" ).append( li );
  tabs.append( "<figure style='height: 800px;' id='" + id + "'></figure>" );
// insert placeholder graph
  myChart = new xChart('line', pgplot_data, '#' + id, pgplot_opts);
  tabs.tabs( "refresh" );
  tabs.tabs("option", "active", tabs.children().length - 2);
}
</script>
<div id="Buttonbar">
<button onclick="new_helper('plot')"><img src="images/graph.gif"/></button>
<button onclick="new_helper('table')"><img src="images/table.gif"/></button>
<div>
<div style="position:absolute;left:0px;width:320px;">
<table border="2"> 
<tr><td colspan="2">
<button type="button" onclick="model_reset()">
<img src="images/stop.gif"></button>
<button type="button" onclick="model_exec()">
<img id="button_op" src="images/play.gif"></button>
<div id="progress" style="width:60%;float:right"></div>
<tr><td>Execute for: </td><td><input id="rl" type="text" name="runlength" 
				     size="8" value=<?php echo $runlength;?>> 
    unit</td></tr>
<tr><td>Current time: </td><td><input id="ct" type="text" name="current" 
				      size="8" value=<?php echo $current;?>> 
    unit</td></tr>
<tr><td>Log each </td><td><input id="le" type="text" name="logstep" size="8"
		value=<?php echo $logstep;?>> unit</td></tr>
<tr><td>Time step: </td><td><input id="ts" type="text" name="step" size="8"
		  value=<?php echo $step;?>> unit</td></tr>
</table>
<div id="explorer"></div>
<?php
unset($mdlArr);
for($x=0;$x<$arrlength;$x++)
  {
    $path = $_SESSION['paths'][$x];
    $nicePath = escapeNasties($path);
// all nodes will go in data structure...?
    unset($mdlLine);
    $id = doTcl("getnodeid [set mH] " . $nicePath);
    $tailDiv = strrpos($nicePath, '/');
    $parentPath = substr($nicePath, 0, $tailDiv);
    if (strlen($parentPath)) {
       $mdlLine["parent"] = doTcl("getnodeid [set mH] " . $parentPath);
    } else {
       $mdlLine["parent"] = "#";
    }
    $mdlLine["icon"] = "images/" . doTcl("GetModelProperty [set mH] " 
	      . $nicePath . ' Class') . ".gif";
    $mdlLine["text"] = substr($nicePath, $tailDiv+1);
    $mdlLine["equation"] = doTcl("GetModelProperty [set mH] " . $nicePath
	      . ' Spec');
    $mdlLine["comment"] = doTcl("GetModelProperty [set mH] " . $nicePath
	      . ' Comment');
    $mdlArr[$id] = $mdlLine;
  };
echo "
</div>
<script>
var model_json = " . json_encode($mdlArr);?>;

var treeData = [], treeLine;
for (var id in model_json) {
   treeLine = model_json[id];
   treeLine.id = id;
   treeData.push(treeLine);
}

$('#explorer').jstree({ 'core' : {
    'data' : treeData
} });
</script>
<div id="tabs" style="margin-left:320px;">
<ul>
<li><a href="#tabs-1">Model diagram</a></li>
</ul>
<div id="tabs-1">
<div>
<button type="button" onclick="SvgDiagZoom(0.8)">Zoom Out</button>
<button type="button" onclick="SvgDiagZoom(1.25)">Zoom In</button>
</div>
<div style="height:800px;overflow-x:auto;overflow-y:auto">
<?php
if (file_exists($_SESSION['svgImage'])) {
  $svgStm = fopen($_SESSION['svgImage'], "r");
  while (!feof($svgStm) && strpos($svgLine, "<svg ") !== 0) {
    $svgLine = fgets($svgStm);
  }
  // passed boilerplate to start of svg object -- insert this line
  echo preg_replace('/^<svg /', '$0id="mod_diag" ', $svgLine);
  while (!feof($svgStm)) {
    echo fgets($svgStm);
  }
  fclose($svgStm);
}
?>
</div> 
</div> 
</div>
</body>
