<?php
function escapeNasties ($str) {
   return addcslashes($str, "][{};#$\\\ \n\r\t");
}

function demangle($bs) {
// on some systems the double quotes in the original Javascript all
// somehow get prepended with a backslash -- add one to match string if so
   return str_replace(array('"',':-'), array('\'',': -'), $bs);
// above " does not start string
}

function doTcl($cmd) {
// Version using INET sockets -- ungainly and insecure
//   $fp = fsockopen("localhost", $_POST['port']+0, $errno, $errstr, 30);
// version using UNIX sockets -- it's all about the base
   $fp = fsockopen("unix://" . $_POST['base'] . ".uxs", -1,
       $errno, $errstr, 30);
   if (!$fp) {
      exit("$errstr ($errno) " . sprintf('%o', fileperms($_POST['base'] . ".uxs")). "<br />\n");
   } else {
//       echo $cmd . " ==> ";
      fwrite($fp, $cmd . "\n");
      $resp = str_replace("\r", "", stream_get_contents($fp));
//       echo $resp . "<br>\n";
      fclose($fp);
   }
   return substr($resp,0,-1);
}

header('Content-Type: text/html; charset=utf-8');
include 'config.php';
if ($_POST['act'] != "BuildShareLibInLine") {
   // only do for AJAX requests, produces warning if inline
   header('Access-Control-Allow-Origin: *');
}

switch ($_POST['act']) {
   case "ConvertJSON":
   $base = tempnam('/tmp', 'jsm');

   $hole = popen($cgiRel . '/gconvert ' . $base . '.sml', 'w');
   if ($hole) {
     fwrite($hole, demangle($_POST['js_mod']));
     if (pclose($hole) == -1) {
       exit('Error in translation');
     }
   } else {
     exit('Could not open translator');
   }
   echo $base;
   break;

   case "SaveProlog":
   $base = tempnam('/tmp', 'plm');

   $plStm = fopen($base . ".sml", "w");
   fwrite($plStm, str_replace(array('"','\n'), array('',"\n"), $_POST['pl_mod']));
   fclose($plStm);

   echo $base;
   break;

   case "BuildShareLib":
   case "BuildShareLibInLine":
$tculargs = array($simileLocn, $simileHome, $_POST['base']);
$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

$process = proc_open($cgiRel . "/tcular.cgi " . implode(" ", $tculargs),
    $descriptorspec, $pipes);
if (! is_resource($process)) { exit('Failed to start build process'); }

// $pipes now looks like this:
// 0 => writeable handle connected to child stdin
// 1 => readable handle connected to child stdout
// Any error output will be appended to /tmp/error-output.txt

// prevent browser hanging if process requests input for some reason
fwrite($pipes[0], "\n");
fwrite($pipes[0], "\n");
fwrite($pipes[0], "\n");
$pipe_contents = stream_get_contents($pipes[1]);
// echo " Pipe contents: $pipe_contents<br>";

fclose($pipes[0]);
fclose($pipes[1]);

// It is important that you close any pipes before calling
// proc_close in order to avoid a deadlock
$return_value = proc_close($process);

if ( file_exists($_POST['base'] . ".so")) {
   if ($_POST['act'] == "BuildShareLib") {
//  return last line of $pipe_contents for execution parameters
//       echo end(explode("\n", $pipe_contents));
//	 echo substr($pipe_contents,strrpos($pipe_contents,"\n")+1,strlen($pipe_contents));
       echo $pipe_contents; // whole lot for debugging purposes, js will trim
    }
} else {
   echo "Command returned $return_value<br>";
   echo "Output from build process was:<br>";
   echo str_replace("\n", "<br>\n", $pipe_contents);
   echo "<br>Error messages:<br>" . file_get_contents('/tmp/error-output.txt');
   exit('Failed to build executable');
}
break;

case "GetAsmJs":
   $shlibName = pathinfo($_POST['base'],PATHINFO_FILENAME);
   $tculargs = array($simileLocn, $simileHome, $emPath, $_POST['base'],
   	     $shlibName);
   $knob = popen($cgiRel . "/tcular_clexec.cgi " . implode(" ", $tculargs),
	'r');
   $pipe_contents = stream_get_contents($knob);
   // echo "<!-- Pipe contents: $pipe_contents -->";
   fclose($knob);

   $asmStm = fopen($simileHome . "/" . $shlibName . ".asm.js", "r");
   if ($asmStm) {
      $rps = substr($pipe_contents,strrpos($pipe_contents,"\n")+1,strlen($pipe_contents));
      echo "pipeBits = $rps;" . stream_get_contents($asmStm);
      fclose($asmStm);
   } else {
      $asmStm = fopen($simileHome . "/" . $shlibName . ".msg", "w");
      fwrite($asmStm, $pipe_contents);
      echo "pipeBits = 'sent_to_file';"; // hopefully error messages
      fclose($asmStm);
   }
   break;

   case "CreateSocket":
   
$tculargs = array($simileLocn, $simileHome, $_POST['base']);
$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
//   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   1 => array("file", "/tmp/std-output.txt", "a"), // stdout is a file to write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

$process = proc_open($cgiRel . "/socketizer.cgi " . implode(" ", $tculargs),
    $descriptorspec, $clPipes);
if (! is_resource($process)) { exit('Failed to start test process'); }
// UNIX sockets: id is temp filename so no return value needed or supplied
echo "UNIX socket created";

// Version using INET sockets -- ungainly and insecure
// // For sensible php: socket id is echoed
// $port = rtrim(fgets($clPipes[1]));
// if (intval($port)) {
//    echo $port;
// } else {
//    echo file_get_contents("/tmp/error-output.txt");
// }
break;

// for OLD php: do this to get socket instead
   case "WaitSocket":
   $rdyFile = $_POST['base'] . ".uxs";
   while (!file_exists($rdyFile)) sleep(1);
   doTcl("set ::web_service(node) DUMMY");
   doTcl("ResponseTo [list act CreateSocket]");
   echo 'UNIX socket';
//   echo file_get_contents($rdyFile);
//   unlink($rdyFile);
break;
  
   case "GetSVG":
// put the svg in a variable so I can start thinking about how to replace it
      $svgStm = fopen($_POST['base'] . ".svg", "r");
      if ($svgStm === FALSE) {
         echo 'SVG file not found';
	 break;
      }
      $svgLine = "";
      while (!feof($svgStm) && strpos($svgLine, "<svg ") !== 0) {
        $svgLine = fgets($svgStm);
      }
// passed boilerplate to start of svg object -- insert this line
//       echo preg_replace('/^<svg /', '$0id="mod_diag" ', $svgLine);
      echo $svgLine;
// add a group round all the contents so they can be translated in Chromium
// (group was previously in a <defs> element to allow inclusion by reference)
      echo '<g id="mod_diag">';
      while (!feof($svgStm)) {
        echo fgets($svgStm);
      }
      echo "</g>";
      fclose($svgStm);
      break;

   case "GetXMLHelperSetup":
      $helperSet = $_POST['base'] . '.shf';
      if (file_exists($helperSet)) {
         echo str_replace("\r", "", file_get_contents($helperSet));
      }
      break;

   case "LoadSPF":
      if (file_exists($_POST['base'] . '.spf')) {
         doTcl("ConsultParameterMetafile [set iH] " . $_POST['base'] . '.spf');
	 // above should create empty paramData for all parameters
	 $fullSet = doTcl("join [array names paramData] .");
	 $notMissing = explode(".", $fullSet);
	 $gotAll = 1;
      	 for($x=0;$x<count($notMissing);$x++) {
	    $pName = escapeNasties($notMissing[$x]);
	    if ($pName != 'needed' &&
	       		doTcl("set paramData($pName)") == "" &&
			doTcl("GetModelProperty [set mH] [TrimDTFromPath $pName] Class") != "SUBMODEL") {
	       $gotAll = 0;
	       break;
	    }
	 }
	 echo $gotAll;
      } else {
         echo -1;
      }
      break;
      
   case "Exit":
      $base = $_POST['base'];
      doTcl("file delete -force $base");
      doTcl("file delete -force $base" . ".smx");
      doTcl("file delete -force $base" . ".svg");
      doTcl("exit");
      break;

   default:
// general-purpose web_embed call, should do everything
      $origReq = json_encode($_POST);
      $respCmd = "ResponseTo [::json::json2dict [list $origReq]]";
      doTcl("set model_id [set mH]");
      $baseLoc = $_POST['base'];
      doTcl("set service($baseLoc) [set iH]");
      echo doTcl($respCmd);
}
?>
