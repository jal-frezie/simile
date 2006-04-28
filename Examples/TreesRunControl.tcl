# Only needed when running from Wish shell in Unix; package must be put in
# auto_path if not using shell distributed with Simile
package require SimileAutoObj

similescript::ModelWindow modelWin
modelWin UseMRE false
modelWin Show
modelWin Open "../Examples/forestV4IP.sml"
modelWin Run

# Create a runControl command/object with which to control
# (as you might expect) the run control.
similescript::RunControl runControl

set rc runControl
$rc GetIntegrationMethod
$rc SetIntegrationMethod {4th-order Runge-Kutta}
$rc SetIntegrationMethod Euler
$rc SetIntegrationMethodRungeKutta
$rc SetIntegrationMethodEuler
$rc Start
$rc GetCurrentTime
$rc Reset
$rc GetTimeStep 1
$rc SetTimeStep 1 1
$rc GetExecuteFor
$rc SetExecuteFor 250
$rc GetCurrentTime
$rc GetDisplayInterval
$rc SetDisplayInterval 2
$rc GetDisplayInterval
$rc GetNumberOfTimeSteps
after 500
$rc Reset
$rc Reset; # BRKS this once
$rc Start

# note original units, set each possible time units and then revert to original
# GetTimeUnits: unit second minute hour day week month year Ma
set origUnits [$rc GetTimeUnits]
foreach u {unit second minute hour day week month year Ma} {
  $rc SetTimeUnits $u
  puts [$rc GetTimeUnits]
  update
  after 1000
}
$rc SetTimeUnits $origUnits 


$rc GetPhaseCount
set paths [$rc GetAllPaths]

foreach path $paths {
  puts ""
  puts $path
  puts " type:  [$rc GetModelType $path]"
  puts " eval:  [$rc GetModelEval $path]"
  puts " class: [$rc GetModelClass $path]"
  puts " dims:  [$rc GetModelDims $path]"
  puts " min:   [$rc GetMinValue $path]"
  puts " max:   [$rc GetMaxValue $path]"
}

