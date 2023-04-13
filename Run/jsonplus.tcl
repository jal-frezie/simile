package require json 1.3

# word token any atom not just TRUE etc
namespace eval ::json {
    variable wordRE {[A-Za-z][A-Za-z0-9]*}

    variable tokenRE "$singleCharTokenRE|$stringRE|$wordRE|$numberRE"
}

proc ::json::isWord {token} {
    variable wordRE
    
    regexp ^$wordRE$ $token
}

proc ::json::parseObjectMember {tokens nrTokens tokenCursorName objectDictName} {
    upvar $tokenCursorName tokenCursor
    upvar $objectDictName objectDict

    set token [lindex $tokens $tokenCursor]
    set tc $tokenCursor
    incr tokenCursor

# start custom bit
    if {[isWord $token] || [string is double -strict $token]} {
	set token \"$token\"
    }
# end custom bit
    set leadingChar [string index $token 0]
    if {$leadingChar eq "\""} {
        set memberName [unquoteUnescapeString $tc $token]

        if {$tokenCursor == $nrTokens} {
            unexpected $tokenCursor "END" "\":\""
        } else {
            set token [lindex $tokens $tokenCursor]
            incr tokenCursor

            if {$token eq ":"} {
                set memberValue [parseValue $tokens $nrTokens tokenCursor]
                dict set objectDict $memberName $memberValue
            } else {
                unexpected $tokenCursor $token "\":\""
            }
        }
    } else {
# change error to indicte WORD allowed here
        unexpected $tokenCursor $token "STRING WORD"
    }
}

proc ::json::parseArrayElements {tokens nrTokens tokenCursorName resultName} {
    upvar $tokenCursorName tokenCursor
    upvar $resultName result

# initialize indices to value below first
    set index 0
    while true {
# make it a dict by inserting counting indices
        lappend result [incr index] [parseValue $tokens $nrTokens tokenCursor]

        if {$tokenCursor == $nrTokens} {
            unexpected $tokenCursor "END" "\",\"|\"\]\""
        } else {
            set token [lindex $tokens $tokenCursor]
            incr tokenCursor

            switch -exact $token {
                "," {
                    # continue
                }
                "\]" {
                    break
                }
                default {
                    unexpected $tokenCursor $token "\",\"|\"\]\""
                }
            }
        }
    }
}

proc ::json::parseValue {tokens nrTokens tokenCursorName} {
    upvar $tokenCursorName tokenCursor

    if {$tokenCursor == $nrTokens} {
        unexpected $tokenCursor "END" "VALUE"
    } else {
        set token [lindex $tokens $tokenCursor]
	set tc $tokenCursor
        incr tokenCursor

        set leadingChar [string index $token 0]
        switch -exact -- $leadingChar {
            "\{" {
                return [parseObject $tokens $nrTokens tokenCursor]
            }
            "\[" {
                return [parseArray $tokens $nrTokens tokenCursor]
            }
            "\"" {
                # quoted string
                return [unquoteUnescapeString $tc $token]
            }
            default {
                # number?
# treat bareword as number here
                if {[isWord $token] || [string is double -strict $token]} {
                    return $token
                } else {
                    unexpected $tokenCursor $token "VALUE"
                }
            }
        }
    }
}
