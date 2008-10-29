# On Macs with pre-installed Wish, a Trf2.1 is included which does things
# differently to the one we supply. To avoid loading it by accident we load
# ours as part of the dummy package MyTrf.
# Hopefully fixed now by not adding tcl_pkgPath dirs to auto_path in init.tcl
package ifneeded Trf 2.1 \
    [list source [file join $dir Trf.tcl]]
