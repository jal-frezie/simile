# dummy package, we do not need Trf but R interface tries to load it
# so having this stops failure error
package ifneeded Trf 2.2 [list package provide Trf 2.2]
