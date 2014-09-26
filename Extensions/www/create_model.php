<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>Simile model execution</title>
<link rel="stylesheet" href="dist/themes/default/style.css" />
<link href="css/humanity/jquery-ui-1.10.4.custom.css" rel="stylesheet" />
<link href="css/xcharts.min.css" rel="stylesheet" />
<link href="//cdn.datatables.net/1.10.0/css/jquery.dataTables.css" rel="stylesheet" />
<script src="js/jquery-1.10.2.js"></script>
<script src="js/jquery-ui-1.10.4.custom.js"></script>
<script src="dist/jstree.min.js"></script>
<script src="http://d3js.org/d3.v3.min.js" charset="utf-8"></script>
<script src="js/xcharts.min.js"></script>
<script src="//cdn.datatables.net/1.10.0/js/jquery.dataTables.js"></script>
<script src="//cdn.datatables.net/plug-ins/be7019ee387/api/page.jumpToData().js"></script>
<style>
#tabs li .ui-icon-close { float: left; margin: 0.4em 0.2em 0 0; cursor: pointer; }
.axis path, .axis line {
  fill: none;
  stroke: #bbb;
}

rect.pane {
  cursor: move;
  fill: none;
  pointer-events: all;
}

</style>
<?php
include_once "make_exec.php";

if (isset($_POST['dropbox_link'])) {
//   echo "Got model link:" . $_POST['dropbox_link'] . "<br>";
   $base = tempnam('/tmp', 'dbx');
   file_put_contents($base, file_get_contents($_POST['dropbox_link']));
} elseif (isset($_POST['js_mod'])) {
   $base = tempnam('/tmp', 'jsm');
// on this system the double quotes in the original Javascript all
// somehow get prepended with a backslash
   $preproc = str_replace(array('\\"',':-'), array('\'',': -'), $_POST['js_mod']);
// above " does not start string

   $hole = popen('../cgi-bin/gconvert ' . $base, 'w');
   if ($hole) {
     fwrite($hole, $preproc);
     if (pclose($hole) == -1) {
       exit('Error in translation');
     }
   } else {
     exit('Could not open translator');
   }
} else {
   $allowedExts = array("sml", "pl");
   $extension = pathinfo($_FILES["notconfusing"]["name"],PATHINFO_EXTENSION);
   if ($_FILES["notconfusing"]["size"] > 20000000) { exit('File too big'); }
   if (! in_array($extension, $allowedExts)) {
      exit('Bad file extension: ' . $extension);
   }
   if ($_FILES["notconfusing"]["error"] > 0) {
      exit('Return code: ' . $_FILES["notconfusing"]["error"]);
   }
   $base = $_FILES["notconfusing"]["tmp_name"];
//   echo "Upload: " . $_FILES["notconfusing"]["name"] . "<br>";
//   echo "Type: " . $_FILES["notconfusing"]["type"] . "<br>";
//   echo "Size: " . ($_FILES["notconfusing"]["size"] / 1024) . " kB<br>";
}
//echo "Temp file: " . $base . "<br>";
CreateModelExec($base);

// web site starts here
echo "<script>\nvar fileBase = '$base';\n</script>";
echo "<script src='run.js'></script>";

?> 
</head>
<body onload="prepare()">
<div id="Buttonbar">
<button onclick="new_helper('plot')"><img src="images/graph.gif"/></button>
<button onclick="new_helper('table')"><img src="images/table.gif"/></button>
<button onclick="new_helper('sliders')"><img src="images/slider.gif"/></button>
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
				     size="8" value=100> 
    unit</td></tr>
<tr><td>Current time: </td><td><input id="ct" type="text" name="current" 
				      size="8" value=0> 
    unit</td></tr>
<tr><td>Log each </td><td><input id="le" type="text" name="logstep" size="8"
		value=1> unit</td></tr>
<tr><td>Time step: </td><td><input id="ts" type="text" name="step" size="8"
		  value=0.1> unit</td></tr>
</table>
<div id="explorer"></div>
</div>
<div id="tabs" style="margin-left:320px;">
<ul>
<li><a href="#tabs-1">Model diagram</a></li>
</ul>
<div id="tabs-1">
<div>
<button type="button" onclick="SvgDiagZoom(0.8)">Zoom Out</button>
<button type="button" onclick="SvgDiagZoom(1.25)">Zoom In</button>
</div>
<div id="holds_svg" style="height:800px;overflow-x:auto;overflow-y:auto">
</div> 
</div> 
</div>
</body>
