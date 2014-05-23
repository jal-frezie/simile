<?php
function escapeNasties ($str) {
   return addcslashes($str, "][{};#$ \\\n\t");
}

function doTcl($cmd) {
   $fp = fsockopen("localhost", $_SESSION['svrPort'], $errno, $errstr, 30);
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
   return rtrim($resp);
}
?>
