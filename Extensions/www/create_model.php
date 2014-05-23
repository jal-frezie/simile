<html>
<head>
<title>Simile model compiler</title>
<body>
<?php
if (isset($_POST['dropbox_link'])) {
   echo "Got model link:" . $_POST['dropbox_link'] . "<br>";
   $base = tempnam('/tmp', 'dbx');
   file_put_contents($base, file_get_contents($_POST['dropbox_link']));
} elseif (isset($_POST['js_mod'])) {
   $preproc = str_replace(array('"',':-'), array('\'',': -'), $_POST['js_mod']);
// above " does not start string
   $base = tempnam('/tmp', 'jsm');

   $hole = popen('../cgi-bin/gconvert ' . $base, 'w');
   fwrite($hole, $preproc);
   pclose($hole);
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
   echo "Upload: " . $_FILES["notconfusing"]["name"] . "<br>";
   echo "Type: " . $_FILES["notconfusing"]["type"] . "<br>";
   echo "Size: " . ($_FILES["notconfusing"]["size"] / 1024) . " kB<br>";
}
echo "Temp file: " . $base . "<br>";

$shlibName =     pathinfo($base,PATHINFO_FILENAME) . ".so";
$simileLocn = "/usr/lib64/simile-6.1";
$simileHome =  "/tmp/upload";
$tculargs = array($simileLocn, $simileHome, $base, $shlibName);

$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("file", "/tmp/error-output.txt", "a") // stderr is a file to write to
);

// Cannot pass target file as env var because that stops default script env
// which tells it e.g., where to find compiler

// $env = array('some_option' => 'aeiou');

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

session_start();
// make sure model data is new
unset($_SESSION['runlength']);
echo "command returned $return_value<br>";
echo "Output from build process was:<br>$pipe_contents";
echo "<br>Error messages:<br>" . file_get_contents('/tmp/error-output.txt');

if (! file_exists($simileHome . "/" . $shlibName)) {
   echo "<br>Directory contents:<br>" . var_dump(glob('/tmp/*'));
   exit('Failed to build executable');
}

// success: script exited, now invoke the tcl 5d client to play with
// the model. I am going to try to use the exact version that is used by
// the R interface, without any extra Tcl script. This may be foolhardy.

include_once "model_action.php";
$process = proc_open("../cgi-bin/socketizer.cgi " . implode($tculargs, " "), 
    $descriptorspec, $clPipes);
$_SESSION['svrPort'] = rtrim(fgets($clPipes[1]));
// tcular has exported the svg image to upload location .svg
$_SESSION['svgImage'] = $base . ".svg";
echo "Started server on port " . $_SESSION['svrPort'];
$pCount = doTcl('llength [set hook]');
echo "<br>Number of model params is " . $pCount;
if ($pCount>0) {
// idiom converts tcl list to php array by passing .-separated string
   $_SESSION['modelParams'] = explode(".", doTcl("join [set hook] ."));
   echo "<br><a href=params.php?" . htmlspecialchars(SID) . ">Now enter model parameters</a>";
} else {
   echo "<br><a href=run.php?" . htmlspecialchars(SID) . ">Now run the model</a>";
}
?> 

</body>
