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
   $fp = fsockopen("localhost", $_POST['port'], $errno, $errstr, 30);
   if (!$fp) {
      echo "$errstr ($errno)<br />\n";
      return;
   } else {
//       echo $cmd . " ==> ";
      fwrite($fp, $cmd . "\n");
      $resp = str_replace("\r", "", stream_get_contents($fp));
//       echo $resp . "<br>\n";
      fclose($fp);
   }
   return substr($resp,0,-1);
}

header('Access-Control-Allow-Origin: *');
switch ($_POST['act']) {
   case "ConvertJSON":
   $base = tempnam('/tmp', 'jsm');

   $hole = popen('../cgi-bin/gconvert ' . $base, 'w');
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
$shlibName =     pathinfo($_POST['base'],PATHINFO_FILENAME) . ".so";
$simileLocn = "/usr/lib/simile-6.2";
$simileHome =  "/home/www-data";
$tculargs = array($simileLocn, $simileHome, $_POST['base'], $shlibName);
$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

$process = proc_open("../cgi-bin/tcular.cgi " . implode($tculargs, " "),
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

if (! file_exists($simileHome . "/" . $shlibName)) {
   echo "Command returned $return_value<br>";
   echo "Output from build process was:<br>$pipe_contents";
   echo "<br>Error messages:<br>" . file_get_contents('/tmp/error-output.txt');
   echo "<br>Directory contents:<br>" . var_dump(glob('/tmp/*'));
   exit('Failed to build executable');
}
break;

   case "CreateSocket":
$shlibName =     pathinfo($_POST['base'],PATHINFO_FILENAME) . ".so";
$simileLocn = "/usr/lib/simile-6.2";
$simileHome =  "/home/www-data";
$tculargs = array($simileLocn, $simileHome, $_POST['base'], $shlibName);
$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

$process = proc_open("../cgi-bin/socketizer.cgi " . implode($tculargs, " "), 
    $descriptorspec, $clPipes);
if (! is_resource($process)) { exit('Failed to start test process'); }
//$port = rtrim(fgets($clPipes[1]));
//if (intval($port)) {
//   echo $port;
//} else {
//   echo file_get_contents("/tmp/error-output.txt");
//}
break;

   case "WaitSocket":
   $rdyFile = $_POST['base'] . ".rdy";
   while (!file_exists($rdyFile)) sleep(1);
   echo file_get_contents($rdyFile);
   unlink($rdyFile);
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
      while (!feof($svgStm)) {
        echo fgets($svgStm);
      }
      fclose($svgStm);
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
          $mdlArr[$id] = $mdlLine;
        } else {
           $mdlArr[$id] = doTcl("GetJsonValues [set iH] $nicePath");
        }
      }
      echo json_encode($mdlArr);
      break;

   case "Parameterize":
//      $goer = '{"/fixie":"56.7","/freeweel":"0 40 50 80"}';
      $sample =  str_replace(array('\\"'), array('"'), $_POST['data']);
//      echo $goer . '<===>' . $sample;
//      break;
//      $spew = [];
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
      $pop = doTcl("DoResetModel [set iH] $current Euler " . $_POST['note']);
      echo $pop;
      break;

   case "Execute":
   case "ExecuteMulti":
      $runlength = $_POST['runlength'];
      $current = $_POST['current'];
      $step = $_POST['step'];
      $log = $_POST['log'];

      doTcl("c_setstepmodel [set iH] $step 1");
      $note = explode(",",$_POST['note']);
      $endPt = $current + $runlength;

      for($t=$current;$t<$endPt;$t+=$log) {
         $endInt = $t + $log;
	 if ($endInt > $endPt) {
	     $endInt = $endPt;
	 }
	 doTcl("DoExecuteModel [set iH] Euler $t $endInt 0 0");
	 for($x=0;$x<count($note);$x++) {
            $val = doTcl("GetJsonValuesById [set iH] " . $note[$x]);
// if ExecuteMulti the time points are outer indices
            if ($_POST['act'] == "Execute") {
               $hlpArr[$note[$x]][$endInt] = $val;
	    } else {
               $hlpArr[$endInt][$note[$x]] = json_decode($val);
	    }
      	 }
      }
      echo json_encode($hlpArr);
      break;
   case "Exit":
      $base = $_POST['base'];
      doTcl("file delete -force $base");
      doTcl("file delete -force $base" . ".smx");
      doTcl("file delete -force $base" . ".svg");
      doTcl("exit");
}
?>
