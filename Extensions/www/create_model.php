<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>Simile model execution</title>
<link rel="stylesheet" href="dist/themes/default/style.css" />
<link href=" jquery-ui.min.css" rel="stylesheet" />
<!-- link href="css/xcharts.min.css" rel="stylesheet" /-->
<link href="css/jquery.jui_dropdown.css" rel="stylesheet" />
<link href="css/jquery.dataTables.css" rel="stylesheet" />
<script src="external/jquery/jquery.js"></script>
<script src="jquery-ui.min.js"></script>
<!-- script src="js/jquery.scrollTo-min.js?1.4.11"></script -->
<script src="dist/jstree.min.js"></script>
<script src="js/d3.v3.min.js" charset="utf-8"></script>
<!-- script src="js/xcharts.min.js"></script-->
<script src="js/jquery.jui_dropdown.js"></script>
<script src="js/jquery.dataTables.js"></script>
<!-- script src="//cdn.datatables.net/plug-ins/be7019ee387/api/page.jumpToData().js"></script -->
<script src="js/three.min.js"></script>
<script src="js/OrbitControls.js"></script>
<script type="text/javascript" src="js/jscolor/jscolor.js"></script>
<script src="js/split.js"></script>
<style>
* {
  margin: 0;
}
html, body {
  height: 100%;
  overflow: hidden; <!-- windows in tab will be sized to notebook parent
and thus be too big once tabs added causing unnecessary scrollbar -->
}

#tabs li .ui-icon-close { float: left; margin: 0.4em 0.2em 0 0; cursor: pointer; }
.axis path, .axis line {
  fill: none;
  stroke: #bbb;
}

.axis text {
   font-family: sans-serif;
   font-size: 12px;
}

rect.pane {
  cursor: move;
  fill: none;
  pointer-events: all;
}

<!-- demo_dropdown 2 ---------------------------------------------------------->
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
  width: 120px;                  
  height: 28px;                 
  padding: 2px;             
  font: 12px sans-serif;        
  background: lightsteelblue;   
  border: 0px;      
  border-radius: 8px;           
  pointer-events: none;         
}
<!-- for panes -->
  .split {
    -webkit-box-sizing: border-box;
       -moz-box-sizing: border-box;
            box-sizing: border-box;

    overflow-y: auto;
    overflow-x: hidden;
  }

  .content {
    border: 1px solid #C0C0C0;
    box-shadow: inset 0 1px 2px #e4e4e4;
    background-color: #fff;
  }

  .gutter {
    background-color: #eee;
    background-repeat: no-repeat;
    background-position: 50%;
  }

  .gutter.gutter-horizontal {
    cursor: col-resize;
    background-image: url('images/grips/vertical.png');
  }

  .gutter.gutter-vertical {
    cursor: row-resize;
    background-image: url('images/grips/horizontal.png');
  }

  .split.split-horizontal, .gutter.gutter-horizontal {
    height: 100%;
    float: left;
  }

</style>
<?php
// include_once "make_exec.php"; model_action now used
include 'config.php';

if (isset($_POST['js_mod'])) {
   $preproc = str_replace(array('"',':-'), array('\'',': -'), $_POST['js_mod']);
// above " does not start string
   $base = tempnam('/tmp', 'jsm');

   $hole = popen($cgiRel . '/gconvert ' . $base . '.sml', 'w');
   fwrite($hole, $preproc);
   pclose($hole);
   $_POST["model_src"] = "systo";
   $_POST["param_src"] = "none";
   $_POST["helper_src"] = "none";
   $_POST['model_link'] = "form";
}

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
   $_POST['model_link'] = "Uploaded";
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

if (isset($crmPath)) {
   // Log the event to the database for display by CRM
   require '../../crm/private/ConnectCRM.php';
   $query = "INSERT INTO crm_similive  (DateTime, IPAddress, ModelURL) ".
   "VALUES ('".date('Y/m/d H:i:s')."', '".
   gethostbyaddr($_SERVER['REMOTE_ADDR'])."', '".
   htmlspecialchars(stripslashes($_POST['model_link']))."')";

   $result = mysql_query($query) or die("Query failed : " . mysql_error());
   mysql_close($link);
}

// CreateModelExec($base);
// OK, now set up _POST so I can inline model_action and get the
// executable...
// $_POST["act"] = "BuildShareLibInLine";
// $_POST["base"] = $base;
// inline: creates executable and sets pipe_contents to run params
// include_once "model_action.php";

// Now build the asm.js
if (isset($_POST['client_exec'])) {
   $shlibName = pathinfo($base,PATHINFO_FILENAME);
   $tculargs = array($simileLocn, $simileHome, $base, $shlibName);
   $knob = popen($cgiRel . "/tcular_clexec.cgi " . implode($tculargs,
      " "), 'r');
   $pipe_contents = stream_get_contents($knob);
   echo "<!-- Pipe contents: $pipe_contents -->";
   fclose($knob);

// web site starts here
   $rps = end(explode("\n", $pipe_contents));
   echo "<script>\n";
   $asmStm = fopen($simileHome . "/" . $shlibName . ".asm.js", "r");
   if ($asmStm) {
      echo stream_get_contents($asmStm);
      fclose($asmStm);
   }

   $helperSet = $base . '.shf';
   if (file_exists($helperSet)) {
      echo "var returnedXML = `" . file_get_contents($helperSet). "`;\n";
   }
   $paramSet = $base . '.spf';
   if (file_exists($paramSet)) {
      echo "var paramXML = `" . file_get_contents($paramSet). "`;\n";
   }
  
  echo "var pipeBits = $rps;\nvar fileBase = '$base';\n</script>";
  echo "<script src='run_clexec.js'></script>";
} else {
  echo "<script>\nvar fileBase = '$base';\n</script>";
  echo "<script src='run.js'></script>";
}
?>
<script src='shapes3d.js'></script>
</head>
<body onload="prepare()">
  <div id="Buttonbar">
    <button title="Plot value against time" onclick="new_helper('plot')"><img src="images/graph.gif"/></button>
    <button title="XY Plot" onclick="new_helper('plotxy')"><img src="images/plotxy.gif"/></button>
    <button title="Table of values" onclick="new_helper('table')"><img src="images/table.gif"/></button>
    <button title="Sliders for inputs" onclick="new_helper('sliders')"><img src="images/slider.gif"/></button>
    <button title="3-D shape viewer" onclick="new_helper('shapes')"><img src="images/3d_objects.png"/></button>
    <button title="Rectangular grid" onclick="new_helper('grid')"><img src="images/grid.gif"/></button>
    <button title="Polygon map" onclick="new_helper('polys')"><img src="images/polys.png"/></button>
  </div>
  <!-- Now put the rest in a set of resizable panes...later -->
  <div id="Left" class="split split-horizontal">
    <div id="topleft" class="split split-vertical">
      <table id="RunControl" border="2" style="width:100%"> 
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
	  <?php
	     if (isset($_POST['client_exec'])) {
	     echo '<tr><td>Display each </td>
	     <td><input id="de" type="text" name="runstep" size="8" value=1>
	       <label class=unit>unit</label></td></tr>';
	  } else {
	  echo '<tr><td>Update each </td>
	    <td><input id="ue" type="text" name="runstep" size="8" value=10>
	      <label class=unit>unit</label></td></tr>
	  <tr><td>Log each </td>
	    <td><input id="le" type="text" name="logstep" size="8" value=1>
	      <label class=unit>unit</label></td></tr>';
	  }
	  ?>
	  <tr><td>Time step(s): </td><td><input id="ts" type="text" name="step" size="8"
						value=0.1> <label class=unit>unit</label></td></tr>
      </table>
      </div>
    <div id="explorer" class="split split-vertical" style="overflow:auto"></div>
  </div>
  <div id="right" class="split split-horizontal">
  <!--div id="tabs" class="ui-layout-center" style="height:100%">
    <ul>
      <li><a href="#tabs-0">Model diagram</a></li>
    </ul>
    <div id="tabs-0">
      <div id="holds_svg" style="position: absolute">
	<?php
	   if (isset($_POST['client_exec'])) {
	   // put the svg in a variable so I can start thinking about how to replace it
	   $svgStm = fopen($base . ".svg", "r");
	   if (!$svgStm) exit('No SVG file found');
	   $svgLine = "";
	   while (!feof($svgStm) && strpos($svgLine, "<svg ") !== 0) {
           $svgLine = fgets($svgStm);
	   }
	   // passed boilerplate to start of svg object -- insert this line
	   echo preg_replace('/^<svg /', '$0id="mod_diag" ', $svgLine);
				     // add a group round all the contents so they can be translated in Chromium
				     echo "<g>";
				     while (!feof($svgStm)) {
				     echo fgets($svgStm);
				     }
				     echo "</g></div>";
				     fclose($svgStm);
				     }
				     ?>
	   </div> 
    </div>
  </div -->
  </div>
  <div id="WaitDialog"   class="hidden" style="text-align: center">
    <img  src="images/ajax-loader.gif" />
    <div style="margin-top: 10px; color: black">
      <b>Please wait</b>
    </div>
  </div>
</body>
