# ::tcom::import F:/Progra~1/Simile/System/lib/SimileAutoObj/SimileAutoObj.tlb; # need path

set tcl_library F:/Progra~1/Simile/System/bin
package require tcom
set mw [::tcom::ref createobject "SimileAutoObj.ModelWindow"]

$mw HideModelWindow
$mw UseMRE 0

$mw FileOpen

$mw BuildCPP





