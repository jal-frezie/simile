package require Tk 8.4-;                 # minimum version for Tile
package require tile 0.8-;               # depends upon tile


namespace eval ttk {
  namespace eval theme {
    namespace eval darkonic {
      variable version 0.1
    }
  }
}

namespace eval ttk::theme::darkonic {

    variable colors
    
  array set colors {
    -disabledfg	"DarkGrey"
    -frame  	"#424242"
    -dark	    "#222222"
    -darker 	"#121212"
    -darkest	"black"
    -lighter	"#626262"
    -lightest 	"#ffffff"
    -selectbg	"#4a6984"
    -selectfg	"#ffffff"
  }
  if {[info commands ::ttk::style] ne ""} {
    set styleCmd ttk::style
  } else {
    set styleCmd style
  }

    set parentTheme classic

  $styleCmd theme create darkonic -parent $parentTheme -settings {

    # -----------------------------------------------------------------
    # Theme defaults
    #
    $styleCmd configure "." \
        -background $colors(-frame) \
        -foreground white \
        -bordercolor $colors(-darkest) \
        -darkcolor $colors(-dark) \
        -lightcolor $colors(-lighter) \
        -troughcolor $colors(-darker) \
        -selectbackground $colors(-selectbg) \
        -selectforeground $colors(-selectfg) \
        -selectborderwidth 0 \
        -font TkDefaultFont \
        ;

    $styleCmd map "." \
        -background [list disabled $colors(-frame) \
        active $colors(-lighter)] \
        -foreground [list disabled $colors(-disabledfg)] \
        -selectbackground [list  !focus $colors(-darkest)] \
        -selectforeground [list  !focus white] \
        ;

    # ttk widgets.
    foreach mapable {TCheckbutton TRadiobutton} {
	eval $styleCmd map $mapable \
	    [$styleCmd theme settings $parentTheme \
		 [list $styleCmd map $mapable]]
    }
    $styleCmd configure TLabelframe -relief groove
    $styleCmd configure TEntry \
        -fieldbackground $colors(-frame) -foreground $colors(-selectfg)
    $styleCmd configure TCombobox \
        -fieldbackground $colors(-frame) -foreground $colors(-selectfg)
    $styleCmd configure TSpinbox \
        -fieldbackground $colors(-frame) -foreground $colors(-selectfg)

    $styleCmd configure TNotebook.Tab -padding {8 4}
    $styleCmd map TNotebook.Tab -background [list \
        selected $colors(-lighter)]

    # tk widgets.
    $styleCmd map Menu \
        -background [list active $colors(-lighter)] \
        -foreground [list disabled $colors(-disabledfg)]

    $styleCmd configure TreeCtrl \
        -background gray30 -itembackground {gray60 gray50} \
        -itemfill white -itemaccentfill yellow

    $styleCmd map Treeview \
        -background [list selected $colors(-selectbg)] \
        -foreground [list selected $colors(-selectfg)]

    $styleCmd configure Treeview -fieldbackground $colors(-lighter)
  }
}

package provide ttk::theme::darkonic $::ttk::theme::darkonic::version
