# to be called from the Simile installation wish84.exe to register the Simile Automation server
# The could be called by installation program .
package require tcom

cd ../lib/SimileAutoObj
::tcom::server register SimileAutoObj.tlb
