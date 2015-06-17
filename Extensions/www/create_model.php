<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>Simile model execution</title>
<link rel="stylesheet" href="dist/themes/default/style.css" />
<link href=" jquery-ui.min.css" rel="stylesheet" />
<!-- link href="css/xcharts.min.css" rel="stylesheet" /-->
<link href="css/jquery.dataTables.css" rel="stylesheet" />
<link href="css/jquery.jui_dropdown.css" rel="stylesheet" />
<script src="external/jquery/jquery.js"></script>
<script src="jquery-ui.min.js"></script>
<!-- script src="js/jquery.scrollTo-min.js?1.4.11"></script -->
<script src="dist/jstree.min.js"></script>
<script src="js/d3.v3.min.js" charset="utf-8"></script>
<!-- script src="js/xcharts.min.js"></script -->
<script src="js/jquery.dataTables.js"></script>
<script src="js/jquery.jui_dropdown.js"></script>
<!-- script src="//cdn.datatables.net/plug-ins/be7019ee387/api/page.jumpToData().js"></script -->
<script src="js/three.min.js"></script>
<script src="js/OrbitControls.js"></script>
<script type="text/javascript" src="js/jscolor/jscolor.js"></script>
<style>
* {
  margin: 0;
}
html, body {
  height: 100%;
  overflow: hidden; /* windows in tab will be sized to notebook parent
and thus be too big once tabs added causing unnecessary scrollbar */
}

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

/* demo_dropdown 2 ---------------------------------------------------------- */
.container2 {
  margin: 20px 30px 10px 30px ;
  display: inline-block;
}
 
.menu2 {
  position: absolute;
  width: 120px !important;
  margin-top: 3px !important;
}
 
div.tooltip {   
  position: absolute;           
  text-align: center;           
  width: 60px;                  
  height: 28px;                 
  padding: 2px;             
  font: 12px sans-serif;        
  background: lightsteelblue;   
  border: 0px;      
  border-radius: 8px;           
  pointer-events: none;         
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
      copy($base, $base . ".sml"); // otherwise auto deleted before prepare()
//    echo "Upload: " . $_FILES["model"]["name"] . "<br>";
//    echo "Type: " . $_FILES["model"]["type"] . "<br>";
//    echo "Size: " . ($_FILES["model"]["size"] / 1024) . " kB<br>";
   } else {
      exit('No model supplied!');
   }
   break;

   case "url":
//   echo "Got model link:" . $_POST['model_link'] . "<br>";
   $base = tempnam('/tmp', 'dbx');
   file_put_contents($base . ".sml", file_get_contents($_POST['model_link']));
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

switch ($_POST["helper_src"]) {
   case "file":
   if (is_uploaded_file($_FILES["helpers"]["tmp_name"])) {
      $allowedExts = array("shf");
      $extension = pathinfo($_FILES["helpers"]["name"],PATHINFO_EXTENSION);
      if ($_FILES["helpers"]["size"] > 20000000) { exit('Helper file too big'); }
      if (! in_array($extension, $allowedExts)) {
         exit('Bad helpereter file extension: ' . $extension);
      }
      if ($_FILES["helpers"]["error"] > 0) {
         exit('Return code: ' . $_FILES["helpers"]["error"]);
      }
      copy($_FILES["helpers"]["tmp_name"], $base . ".shf");
   } else {
      exit('No helper setup file supplied!');
   }
   break;

   case "url":
   file_put_contents($base . ".shf", file_get_contents($_POST['helper_link']));
   break;
}

// CreateModelExec($base);
// OK, now set up _POST so I can inline model_action and get the
// executable...
// $_POST["act"] = "BuildShareLibInLine";
// $_POST["base"] = $base;
// inline: creates executable and sets pipe_contents to run params
// include_once "model_action.php";

// web site starts here
// $rps = end(explode("\n", $pipe_contents));
echo "<script>\nvar fileBase = '$base';\n</script>";
?> 
<script src='run.js'></script>
</head>
<body onload="prepare()">
<div id="Buttonbar">
<button onclick="new_helper('plot')"><img src="images/graph.gif"/></button>
<button onclick="new_helper('plotxy')"><img src="images/plotxy.gif"/></button>
<button onclick="new_helper('table')"><img src="images/table.gif"/></button>
<button onclick="new_helper('sliders')"><img src="images/slider.gif"/></button>
<button onclick="new_helper('shapes')"><img src="images/3d_objects.png"/></button>
<button onclick="new_helper('grid')"><img src="images/grid.gif"/></button>
<button onclick="new_helper('polys')"><img src="images/polys.png"/></button>
</div>
<div id="Left" style="position:absolute;top:2em;bottom:0px;left:0px;width:320px">
<table id="RunControl" border="2"> 
<tr><td colspan="2">
<button type="button" style="width:20%" onclick="model_reset()">
<img src="images/stop.gif"></button>
<button type="button" style="width:20%" onclick="model_exec()">
<img id="button_op" src="images/play.gif"></button>
<div id="progress" style="width:55%;float:right"></div>
<tr><td>Execute for: </td><td><input id="rl" type="text" name="runlength" 
				     size="8" value=100> 
    <label class=unit>unit</label></td></tr>
<tr><td>Current time: </td><td><input id="ct" type="text" name="current" 
				      size="8" value=0> 
    <label class=unit>unit</label></td></tr>
<tr><td>Update each </td><td><input id="ue" type="text" name="runstep" size="8"
		value=10> <label class=unit>unit</label></td></tr>
<tr><td>Log each </td><td><input id="le" type="text" name="logstep" size="8"
		value=1> <label class=unit>unit</label></td></tr>
<tr><td>Time step(s): </td><td><input id="ts" type="text" name="step" size="8"
		  value=0.1> <label class=unit>unit</label></td></tr>
</table>
<div id="explorer" style="overflow:auto"></div>
</div>
<div id="tabs" class="ui-layout-center" style="height:100%;margin-left:320px">
<ul>
<li><a href="#tabs-0">Model diagram</a></li>
</ul>
<div id="tabs-0">
<div>
<!-- button type="button" onclick="SvgDiagZoom(0.8)">Zoom Out</button -->
<!-- button type="button" onclick="SvgDiagZoom(1.25)">Zoom In</button -->
</div>
<div id="holds_svg" style="position: absolute">
</div> 
</div> 
    <div id="WaitDialog"   class="hidden" style="text-align: center">
        <img  src="images/ajax-loader.gif" />
        <div style="margin-top: 10px; color: black">
            <b>Please wait</b>
        </div>
    </div>
</body>
