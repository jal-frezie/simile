<?php
session_start();
include_once "model_action.php";

if (isset($_POST['act'])) {
   $runlength = $_POST['runlength'];
   $current = $_POST['current'];
   $step = $_POST['step'];
   $note = explode(",",$_POST['note']);
   
   doTcl("c_setstepmodel [set iH] " . $step . " 1");
   if ($_POST[act] == "Reset") {
       $current = 0;
       doTcl("ResetModel [set iH] 0 Euler -2");
       echo $current;
   } else {
      $endPt = $current + $runlength;
      doTcl("ExecuteModel [set iH] Euler " . $current . " " . $endPt . " 0 0");
      $current = $endPt;
      for($x=0;$x<count($note);$x++) {
         $hlpArr[$note[$x]] =  doTcl("GetValuesById [set iH] " . $note[$x]);
      }
      echo json_encode($hlpArr);
   }
}
?>
