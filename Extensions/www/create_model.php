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
// include_once "make_exec.php"; model_action now used

switch ($_POST["model_src"]) {
   case "file":
   if (is_uploaded_file($_FILES["model"]["tmp_name"])) {
      $allowedExts = array("sml", "pl");
      $extension = pathinfo($_FILES["model"]["name"],PATHINFO_EXTENSION);
      if ($_FILES["model"]["size"] > 20000000) { exit('Model file too big'); }
      if (! in_array($extension, $allowedExts)) {
         exit('Bad model file extension: ' . $extension);
      }
      if ($_FILES["model"]["error"] > 0) {
         exit('Return code: ' . $_FILES["model"]["error"]);
      }
      $base = $_FILES["model"]["tmp_name"];
//   echo "Upload: " . $_FILES["model"]["name"] . "<br>";
//   echo "Type: " . $_FILES["model"]["type"] . "<br>";
//   echo "Size: " . ($_FILES["model"]["size"] / 1024) . " kB<br>";
   } else {
      exit('No model supplied!');
   }
   break;

   case "url":
//   echo "Got model link:" . $_POST['model_link'] . "<br>";
   $base = tempnam('/tmp', 'dbx');
   file_put_contents($base, file_get_contents($_POST['model_link']));
   break;
}
switch ($_POST["param_src"]) {
   case "file":
   if (is_uploaded_file($_FILES["params"]["tmp_name"])) {
      $allowedExts = array("spf");
      $extension = pathinfo($_FILES["params"]["name"],PATHINFO_EXTENSION);
      if ($_FILES["params"]["size"] > 20000000) { exit('Param file too big'); }
      if (! in_array($extension, $allowedExts)) {
         exit('Bad parameter file extension: ' . $extension);
      }
      if ($_FILES["params"]["error"] > 0) {
         exit('Return code: ' . $_FILES["params"]["error"]);
      }
      copy($_FILES["params"]["tmp_name"], $base . ".spf");
   } else {
      exit('No parameter file supplied!');
   }
   break;

   case "url":
   file_put_contents($base . ".spf", file_get_contents($_POST['param_link']));
   break;
}

// CreateModelExec($base);
// OK, now set up _POST so I can inline model_action and get the
// executable...
$_POST["act"] = "BuildShareLibInLine";
$_POST["base"] = $base;
include_once "model_action.php";

// web site starts here
echo "<script>\nvar fileBase = '$base';\n</script>";
?> 
<script src='run.js'></script>
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
