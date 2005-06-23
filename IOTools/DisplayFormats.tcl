# library file to contain procs to format numeric values for printing
namespace eval DisplayFormat {
    namespace export \
            General Fixed Scientific Percent\
            DMS RadinDMS \
            HHMM HHMMSS \
            YYYYMMDDHHMMSS YYYYMMDD YYYYMMDDHHMMSS \
            Boolean
    
    package require calendar
    
    proc General {val prec} {
        # was VarPrecRender
        if {![string is double $val] || [string is integer $val]} {
       	    return $val
        }
        set regular [format %.${prec}f $val]
        set scientific [format %.${prec}e $val]
        if {$prec >= 3} {
            set shortSci [format %.[expr $prec-3]e $val]
        } else  {
            set shortSci $scientific
        }
        
        if {[string length $scientific]<[string length $regular]} {
            return $scientific
        } else {
            if {$scientific && !$regular} {
                return $shortSci
            } else {
                return $regular
            }
        }
    }
    
    proc Fixed {val dp} {
        return [format %.${dp}f $val]
    }
    
    proc Scientific {val dp} {
        return [format %.${dp}e $val]
    }
    
    proc Percent {var dp} {
        return [Fixed [expr {100*$var}] $dp]%
    }
    
    # val is in degrees returns string degree:minutes:sec
    proc DMS {val dp} {
        if {$val==0} {
            set sign 1
        } else  {
            set sign [expr {int($val/abs($val))}]
        }
        set absval [expr {abs($val)}]
        set degrees_int [expr {$sign*int($absval)}]
        set minutes [expr {($absval-$degrees_int)*60}]
        set minutes_int [expr {int($minutes)}]
        set seconds [expr {int($minutes-$minutes_int)*60}]
        return [format %d:%d:%d $degrees_int $minutes_int $seconds]
    }
    
    proc RadinDMS {val dp} {
        set val [expr {$val*180.0/3.14159}]
        DMS $val
    }
    
    set datevar(ERA) CE
    
    proc YYYYMMDD {val dp} {
        set j [expr {int($val+2415020)}]; # need Rata die (Julian Day here) for 1900 or 1900-1?
        JulianDayToEYMD  $j datevar
        return [format %.4d/%.2d/%.2d  $datevar(YEAR) $datevar(MONTH) $datevar(DAY_OF_MONTH)]
    }
    
    proc HHMM {val dp} {
        set val [expr {24*$val}]
        set hours_int [expr {int($val)}]
        set minutes [expr {($val-$hours_int)*60}]
        set minutes_int [expr {int($minutes)}]
        return [format %.2d:%.2d $hours_int $minutes_int]
    }
    
    proc HHMMSS {val dp} {
        set val [expr {24*$val}]
        set hours_int [expr {int($val)}]
        set minutes [expr {($val-$hours_int)*60}]
        set minutes_int [expr {int($minutes)}]
        set seconds [expr {int(($minutes-$minutes_int)*60)}]
        return [format %.2d:%.2d:%.2d $hours_int $minutes_int $seconds]
    }
    
    proc YYYYMMDDHHMMSS {val dp} {
        set time [expr {$val-int($val)}]
        return "[YYYYMMDD $val $dp] [HHMMSS $time $dp]"
    }
    
    proc Boolean {val dp} {
        if {$val} {
            return true
        } else  {
            return false
        }
    }
    
}; #end namespace
