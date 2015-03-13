<?php
function escapeNasties ($str) {
   return addcslashes($str, "][{};#$ \\\n\t");
}

function demangle($bs) {
// on this system the double quotes in the original Javascript all
// somehow get prepended with a backslash
   return str_replace(array('\\"',':-'), array('\'',': -'), $bs);
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

if ($_POST['act'] != "BuildShareLibInLine") {
   // only do for AJAX requests, produces warning if inline
   header('Access-Control-Allow-Origin: *');
}

switch ($_POST['act']) {
   case "ConvertJSON":
   $base = tempnam('/tmp', 'jsm');

   $hole = popen('cgi-bin/gconvert ' . $base, 'w');
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

   case "BuildShareLib":
   case "BuildShareLibInLine":
   include 'config.php';

$shlibName =     pathinfo($_POST['base'],PATHINFO_FILENAME) . ".so";
$tculargs = array($simileLocn, $simileHome, $_POST['base'], $shlibName);
$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

$process = proc_open($cgiRel . "/tcular.cgi " . implode($tculargs, " "),
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

if ( file_exists($simileHome . "/" . $shlibName)) {
//   echo $pipe_contents
} else {
   echo "Command returned $return_value<br>";
   echo "Output from build process was:<br>";
   echo str_replace("\n", "<br>\n", $pipe_contents);
   echo "<br>Error messages:<br>" . file_get_contents('/tmp/error-output.txt');
   exit('Failed to build executable');
}
break;

   case "CreateSocket":
   include 'config.php';
   
$shlibName =     pathinfo($_POST['base'],PATHINFO_FILENAME) . ".so";
$tculargs = array($simileLocn, $simileHome, $_POST['base'], $shlibName);
$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

$process = proc_open($cgiRel . "/socketizer.cgi " . implode($tculargs, " "), 
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
   echo 'UNIX socket';
//   echo file_get_contents($rdyFile);
//   unlink($rdyFile);
break;
  
   case "GetSVG":
// put the svg in a variable so I can start thinking about how to replace it
      $svgStm = fopen($_POST['base'] . ".svg", "r");
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
      echo "</g>";
      fclose($svgStm);
      break;

   case "GetXMLHelperSetup":
      $helperSet = $_POST['base'] . '.shf';
      if (file_exists($helperSet)) {
         echo str_replace("\r", "", file_get_contents($helperSet));
      }
      break;

   case "Describe":
   case "Report":
      $line1 = doTcl("join [set catalog] .");
      $paths = explode(".", $line1);
      $arrlength=count($paths);

      for($x=0;$x<$arrlength;$x++) {
        $path = $paths[$x];
        $nicePath = escapeNasties($path);
        $id = doTcl("getnodeid [set mH] $nicePath");
        if ($_POST['act'] == "Describe") {
          $tailDiv = strrpos($nicePath, '/');
          $parentPath = substr($nicePath, 0, $tailDiv);
          if (strlen($parentPath)) {
             $mdlLine["parent"] = doTcl("getnodeid [set mH] $parentPath");
          } else {
             $mdlLine["parent"] = "#";
          }
          $mdlLine["icon"] = "images/" 
	      . doTcl("GetModelProperty [set mH] $nicePath Class") . ".gif";
          $mdlLine["text"] = substr($nicePath, $tailDiv+1);
          $mdlLine["captpath"] = $path;
          $mdlLine["equation"] = 
	      doTcl("GetModelProperty [set mH] $nicePath Spec");
          $mdlLine["comment"] = 
	      doTcl("GetModelProperty [set mH] $nicePath Comment");
          $mdlLine["eval"] = 
	      doTcl("GetModelProperty [set mH] $nicePath Eval");
          $mdlLine["min"] = 
	      doTcl("GetModelProperty [set mH] $nicePath MinVal");
          $mdlLine["max"] = 
	      doTcl("GetModelProperty [set mH] $nicePath MaxVal");
          $mdlLine["dims"] = 
	      explode(" ", doTcl("GetModelProperty [set mH] $nicePath Dims"));
          $mdlArr[$id] = $mdlLine;
        } else {
           $mdlArr[$id] = doTcl("GetJsonValues [set iH] $nicePath 1024");
        }
      }
      echo json_encode($mdlArr);
      break;

   case "LoadSPF":
      if (file_exists($_POST['base'] . '.spf')) {
         doTcl("ConsultParameterMetafile [set iH] " . $_POST['base'] . '.spf');
         $line1 = doTcl("join [set paramData(needed)] .");
	 if (strlen($line1)) {
            $missing = explode(".", $line1);
	    echo json_encode($missing);
	 } else {
	    echo "[]";
	 }
      } else {
         echo -1;
      }
      break;

   case "Parameterize":
//      $goer = '{"/fixie":"56.7","/freeweel":"0 40 50 80"}';
      $sample =  str_replace(array('\\"'), array('"'), $_POST['data']);
//      echo $goer . '<===>' . $sample;
//      break;
      $spew = [];
      $updates = json_decode($sample);
      foreach ($updates as $idx => $pv) {
         $nicePath = escapeNasties($idx);
         $result = doTcl("SetParameter [set aH($nicePath)] [list $pv]");
         if ($result== '-1' || $result == '0' || $result == '1') {
         } else {
            $spew[] = $nicePath . "-->" . $result;
         }
      }
      echo json_encode($spew);
      break;

   case "Reset":
      $current = 0;
      $pop = doTcl("DoResetModel [set iH] $current " . $_POST['method'] . " " . $_POST['note']);
      echo $pop;
      break;

   case "Execute":
   case "ExecuteMulti":
      $runlength = $_POST['runlength'];
      $current = $_POST['current'];
      $step = $_POST['step'];
      $log = $_POST['log'];
      $method = $_POST['method'];

      doTcl("c_setstepmodel [set iH] $step 1");
      $note = json_decode($_POST['note']);
      $endPt = $current + $runlength;

      for($t=$current;$t<$endPt;$t+=$log) {
         $endInt = $t + $log;
	 if ($endInt > $endPt) {
	     $endInt = $endPt;
	 }
	 $stop = doTcl("DoExecuteModel [set iH] $method $t $endInt 0 0");
//	 if ($stop != $endInt) {
//	     exit("Model stopped at " . $stop . " running to " . $endInt);
// probably want to make another call to get error message
//	 }
	 for($x=0;$x<count($note);$x++) {
	    if (is_object($note[$x])) { // it's a req for binary data
	       $val = doTcl("GetBinaryValuesById [set iH] " . $note[$x]->node
	           . " " . $note[$x]->bottom . " " . $note[$x]->top);
	    } else {
               $val = json_decode(doTcl("GetJsonValuesById [set iH] "
	           . $note[$x] . " " . 1048576));
	    }
// if ExecuteMulti the time points are outer indices
            if ($_POST['act'] == "Execute") {
               $hlpArr[$note[$x]]["".$endInt] = $val;
	    } else {
               $hlpArr["".$endInt][$x] = $val;
	    }
      	 }
      }
      echo json_encode($hlpArr);
      break;

   case "Query":
// Get values from a component, can be list, binary or distinct
      $base = $_POST['base'];
      $req = json_decode($_POST['note']);
      switch ($req->format) {
         case "list":
      	 $val = json_decode(doTcl("GetJsonValuesById [set iH] "
	           . $req->node . " " . 1048576));
         break;

	 case "binary":
	 $val = doTcl("GetBinaryValuesById [set iH] " . $req->node
	           . " " . $req->bottom . " " . $req->top);
	 break;
// more later
      }
      echo json_encode($val);
      break;
		   
   case "Exit":
      $base = $_POST['base'];
      doTcl("file delete -force $base");
      doTcl("file delete -force $base" . ".smx");
      doTcl("file delete -force $base" . ".svg");
      doTcl("exit");
}
?>
