set msgs(compartment) "Add compartments"
set msgs(flow) "Add flows"
set msgs(variable) "Add variables"
set msgs(influence) "Add influences"
set msgs(submodel) "Add new submodels"
set msgs(relation) "Connect submodels playing roles in a relationship to a relation submodel"
set msgs(condition) "Add conditions for the existence of submodel instances"
set msgs(creation) "Add creation processes to population submodels"
set msgs(immigration) "Add immigration processes to population submodels"
set msgs(reproduction) "Add reproduction processes to population submodels"
set msgs(loss) "Add destruction processes to population submodels"
set msgs(move) "Move components"
set msgs(copy) "Make copies of submodels"
set msgs(ghost) "Create 'ghosts' of components"
set msgs(select) "Select components"
set msgs(delete) "Delete components"
set msgs(rerun) "Run the model, building it if necessary"
set msgs(undo) "Undo operations sequentially"
set msgs(redo) "Redo operations that were undone"
set msgs(customize) "Customize appearance of components (first select type to customize from top row)"
set msgs(find) "Find a component"
set msgs(findmore) "Find more components"
set msgs(exit) "Exit Simile"
set msgs(runenv) "Go to the Run Environment window"
set msgs(snap) "Inspect model variable"

set msgs(sum) "Returns the sum of all elements of the argument(s)"
set msgs(product) "Returns the product of all elements of the argument(s)"
set msgs(place_in) "Returns each term's position, when making an array with makearay -- argument is nesting depth"
set msgs(count) "Returns the number of values in the argument"
set msgs(any) "Returns true if any of the argument elements are true"
set msgs(all) "Returns true if all of the argument elements are true"
set msgs(parent) "Returns the index of the instance from which this one was reproduced, or 0 if this one was created or immigrated"
set msgs(init_time) "Returns the time at which this instance appeared -- argument is dummy"
set msgs(time) "Returns the current time  -- argument is dummy"
set msgs(dt) "Returns the duration of the time step specified by the argument"
set msgs(prev) "Returns the value of this component the given number of time steps ago"
set msgs(makearray) "Returns an array of the given number of values from the first argument"
set msgs(element) "Returns a value from an array according to the second argument"
set msgs(size) "Takes the name of a fixed-membership submodel and if one arg, returns its number of instances or if two, the size of one of its dimensions"
set msgs(least) "Returns the smallest value from an array/list of values"
set msgs(greatest) "Returns the largest value from an array/list of values"
set msgs(colin) "Takes as its one argument an array/list of n scalar elements and returns a random integer between 1 and n with probability proportional to the corresponding elements in the input array/list, calculating a new value each local time step."
set msgs(abs) "Returns absolute difference between argument and zero"
set msgs(ceil) "Rounds argument up to a whole number"
set msgs(floor) "Rounds argument down to a whole number"
set msgs(channel_is) "Argument is an immigration, reproduction or creation channel. Returns true if this individual appeared through that channel."
set msgs(choose) "choose(a,b,c) is shorthand for 'if a then b else c'"
set msgs(exp) "Returns e to the power of a number"
set msgs(fmod) "Returns remainder after dividing first argument by second"
set msgs(gaussian) "Returns values from a gaussian distribution"
set msgs(hypot) "Returns length of hypotenuse of triangle with given base and height"
set msgs(int) "Returns integer part of argument"
set msgs(last) "Returns value of argument from last time step"
set msgs(log) "Returns natural logarithm of argument"
set msgs(log10) "Returns base-10 logarithm of argument"
set msgs(max) "Returns greater of two values"
set msgs(min) "Returns lesser of two values"
set msgs(pow) "Returns first argument to the power of the second"
set msgs(rand_var) "Returns a random number between the two arguments, with a new value every time step"
set msgs(rand_const) "Returns a random number between the two arguments, which stays the same until reset"
set msgs(sqrt) "Returns the square root of the argument. Calling this with a negative argument when running a model in Tcl under a version of Windows other than 95 original on an Intel Celeron processor can lead to mysterious crashes in Microsoft Office applications, especially early in the tax year."

set msgs(initToolbar) "Display component bar in the desktop window when Simile starts, and in new submodel windows if they are large enough."
set msgs(initNavbar) "Display tool bar in the desktop window when Simile starts, and in new submodel windows if they are large enough."
set msgs(initEqnbar) "Display equation bar in the desktop window when Simile starts, and in new submodel windows if they are large enough."
set msgs(bigButtons) "Use alternative (larger) buttons for the tool bar and component bar."
set msgs(desktopDetail) "Sets the initial number of submodel levels to display. This can be changed later with the Window -> Display detail -> Submodels and Relations menu item."
set msgs(maxWinWidth) "Maximum width of a window, prevents new windows for complex submodels coming up huge. Maximum height is 3/4 of this."
set msgs(compChoice) "Models can be compiled and linked using either Microsoft Visual C++ or GNU GCC."
set msgs(compDescPop) "Enable popups for component's equation when pointer hovers on component."
set msgs(compValPop) "Enable popups for component's current value(s) or instance indices when pointer hovers on component."
set msgs(compCmtPop) "Enable popups for component's description and comment text when pointer hovers on component."
set msgs(recentCount) "Save names of recently opened models for display on the File menu."
set msgs(saveExtras) "Save the canvas file to reduce the time initially taken to draw the model diagram."
set msgs(flowRouting) "Draw flows as a series of horizontal or vertical segments."
set msgs(deleteEndToEnd) "Delete all sections of multi-section influences or flows."
set msgs(helperManager) "Use single window to manange run time displays and controls."
set geometryXYexplanation "Set position of the run control window, in the form xy, where x and y specify the desired location of window on the screen, in pixels."
set msgs(runControlPosition) $geometryXYexplanation
set msgs(slidersPosition) $geometryXYexplanation
set msgs(new) "New empty model"
set msgs(open) "Open"
set msgs(print) "Print"
set msgs(save) "Save"
set msgs(flip_v) "Flip the model diagram vertically"
set msgs(flip_h) "Flip the model diagram horizontally"
set msgs(zoomin) "Zoom in"
set msgs(zoomfit) "Zoom to fit"
set msgs(zoomout) "Zoom out"

set help(g\\+\\+) "run/index.htm"
set help(fill_equation) "equations/dialogue.htm"

set url(contents.htm) {Contents}
set url(start/index.htm) {Getting Started}
set url(start/model.htm) {Simple bank account model}
set url(start/step1.htm) {Step 1}
set url(start/step2.htm) {Step 2}
set url(start/step3.htm) {Step 3}
set url(start/step4.htm) {Step 4}
set url(start/step5.htm) {Step 5}
set url(start/step6.htm) {Step 6}
set url(start/step7.htm) {Step 7}
set url(start/step8.htm) {Step 8}
set url(elements/index.htm) {Model Diagram Elements}
set url(elements/compartment.htm) {Compartment}
set url(elements/flow.htm) {Flow arrow}
set url(elements/variable.htm) {Variable}
set url(elements/influence.htm) {Influence}
set url(elements/submodel.htm) {Submodel}
set url(elements/initialiser.htm) {Initialisation}
set url(elements/migrator.htm) {Migration}
set url(elements/reproducer.htm) {Reproduction}
set url(elements/exterminator.htm) {Extermination}
set url(elements/role.htm) {Role arrow}
set url(elements/condition.htm) {Condition}
set url(diagrams/index.htm) {Working with Model Diagrams}
set url(diagrams/node.htm) {Adding node-type elements}
set url(diagrams/arrow.htm) {Adding arrow-type elements}
set url(diagrams/envelope.htm) {Adding submodels}
set url(diagrams/label.htm) {Changing an elements label}
set url(diagrams/move/index.htm) {Moving elements}
set url(diagrams/move/labels.htm) {Labels}
set url(diagrams/move/flow.htm) {Flow valves}
set url(diagrams/move/influence.htm) {Influence arrows}
set url(diagrams/move/role.htm) {Role arrows}
set url(diagrams/move/submodels.htm) {Submodels}
set url(diagrams/delete.htm) {Deleting elements}
set url(diagrams/duplicate.htm) {Duplicating submodels}
set url(diagrams/ghosts.htm) {Creating ghost elements}
set url(diagrams/print.htm) {Printing model diagrams}
set url(diagrams/undo.htm) {Undoing changes}
set url(diagrams/zoom.htm) {Zooming in and out}
set url(diagrams/search.htm) {Searching for a particular variable}
set url(diagrams/rescale.htm) {Rescaling symbol size}
set url(diagrams/detail.htm) {Controlling the detail displayed}
set url(diagrams/preferences/index.htm) {Preferences}
set url(diagrams/preferences/view.htm) {Settings : View}
set url(diagrams/preferences/edit.htm) {Settings : Edit}
set url(diagrams/preferences/build.htm) {Settings : Build}
set url(diagrams/preferences/save.htm) {Settings : Save}
set url(equations/index.htm) {Working with Equations}
set url(equations/introduction.htm) {Introduction to equations}
set url(equations/bar.htm) {Equation bar}
set url(equations/dialogue.htm) {Equation dialogue window}
set url(equations/components.htm) {Components of an equation}
set url(equations/arrays.htm) {Arrays and lists}
set url(equations/dimensions.htm) {Dimensions}
set url(equations/units.htm) {Physical units}
set url(equations/local.htm) {Local names}
set url(equations/functions.htm) {Functions}
set url(equations/builtin.htm) {Built-in functions}
set url(equations/functions/abs.htm) {abs function}
set url(equations/functions/all.htm) {all function}
set url(equations/functions/any.htm) {any function}
set url(equations/functions/ceil.htm) {ceil function}
set url(equations/functions/channel.htm) {channel function}
set url(equations/functions/count.htm) {count function}
set url(equations/functions/dt.htm) {dt function}
set url(equations/functions/element.htm) {element function}
set url(equations/functions/exp.htm) {exp function}
set url(equations/functions/floor.htm) {floor function}
set url(equations/functions/fmod.htm) {fmod function}
set url(equations/functions/greatest.htm) {greatest function}
set url(equations/functions/hypot.htm) {hypot function}
set url(equations/functions/index.htm) {index function}
set url(equations/functions/init_time.htm) {init_time function}
set url(equations/functions/int.htm) {int function}
set url(equations/functions/last.htm) {last function}
set url(equations/functions/least.htm) {least function}
set url(equations/functions/log.htm) {log function}
set url(equations/functions/log10.htm) {log10 function}
set url(equations/functions/makearray.htm) {makearray function}
set url(equations/functions/max.htm) {max function}
set url(equations/functions/min.htm) {min function}
set url(equations/functions/parent.htm) {parent function}
set url(equations/functions/place_in.htm) {place_in function}
set url(equations/functions/pow.htm) {pow function}
set url(equations/functions/prev.htm) {prev function}
set url(equations/functions/product.htm) {product function}
set url(equations/functions/rand_const.htm) {rand_const function}
set url(equations/functions/rand_var.htm) {rand_var function}
set url(equations/functions/size.htm) {size function}
set url(equations/functions/sofar.htm) {sofar function}
set url(equations/functions/sqrt.htm) {sqrt function}
set url(equations/functions/sum.htm) {sum function}
set url(equations/functions/time.htm) {time function}
set url(equations/trig.htm) {Trigonometric functions}
set url(equations/graph.htm) {Graph function}
set url(equations/table.htm) {Table function}
set url(equations/conditions.htm) {Conditional expressions}
set url(equations/boolean.htm) {Boolean expressions}
set url(equations/user.htm) {User-supplied functions}
set url(equations/macro.htm) {Macro definitions}
set url(equations/external.htm) {External procedural functions}
set url(submodels/index.htm) {Working with Submodels}
set url(submodels/dialogue.htm) {Submodel properties dialogue}
set url(submodels/timestep.htm) {Time step index}
set url(submodels/separate.htm) {Build submodel separately}
set url(submodels/movegroups.htm) {Using a submodel to move groups of elements}
set url(submodels/window.htm) {Opening a new window for a submodel}
set url(submodels/save.htm) {Saving a submodel to file}
set url(submodels/load.htm) {Loading a saved submodel as a stand-alone model}
set url(submodels/import.htm) {Loading a saved model as a submodel}
set url(submodels/multiple/fixed.htm) {Multiple-instance submodels: fixed membership}
set url(submodels/multiple/population.htm) {Multiple-instance submodels: population}
set url(submodels/plugplay/index.htm) {Plug-and-play modularity using submodels}
set url(submodels/plugplay/plugplay1.htm) {Step 1}
set url(submodels/plugplay/plugplay2.htm) {Step 2}
set url(submodels/plugplay/plugplay3.htm) {Step 3}
set url(submodels/plugplay/plugplay4.htm) {Step 4}
set url(submodels/plugplay/plugplay5.htm) {Step 5}
set url(submodels/plugplay/plugplay6.htm) {Step 6}
set url(submodels/conditional.htm) {Conditional submodels}
set url(submodels/association/index.htm) {Association submodels}
set url(submodels/association/introduction.htm) {Introduction to association submodels}
set url(submodels/association/example.htm) {Worked example of association submodels}
set url(submodels/association/single.htm) {Single role arrow}
set url(submodels/association/dual.htm) {Two role arrows - two objects}
set url(submodels/association/double.htm) {Two role arrows - one object}
set url(run/index.htm) {Running Models}
set url(run/build.htm) {Building models}
set url(run/single.htm) {Single-window run-time environment}
set url(run/multiple.htm) {Multiple-window run-time environment}
set url(run/tools/explorer.htm) {Model explorer}
set url(run/control.htm) {Run control}
set url(run/sliders.htm) {Sliders}
set url(run/tools/index.htm) {Working with helpers}
set url(run/tools/plotter.htm) {Plotter helper}
set url(run/tools/table.htm) {Data table helper}
set url(run/tools/configurations.htm) {Helper configurations}
set url(run/tools/others.htm) {Using other helpers}
set url(run/tools/timeplot.htm) {Plot value against time helper}
set url(run/tools/lollipop.htm) {Lollipop diagram helper}
set url(run/tools/grid.htm) {Spatial grid display helper}
set url(run/tools/3d.htm) {3d viewer helper}
set url(run/tools/profiles.htm) {Time profiles helper}
set url(data/index.htm) {Working with External Data}
set url(data/overview.htm) {Overview of the scenario file mechanism}
set url(data/scenario.htm) {Using the scenario file mechanism}
set url(data/case1.htm) {Case 1: providing a single value for a scalar variable}
set url(data/case2.htm) {Case 2: providing a set of values for a variable inside a multiple-instance submodel: values stored in the scenario file}
set url(data/case3.htm) {Case 3: providing a set of values for an array variable: values stored in the scenario file}
set url(data/case4.htm) {Case 4: providing a set of values for a variable in a fixed-membership multiple-instance submodel: values stored in a separate file}
set url(data/case5.htm) {Case 5: providing a set of values for an array variable: values stored in a separate file}
set url(data/case6.htm) {Case 6: providing time-series data}
set url(data/modify.htm) {Modifying scenario values during a session}
set url(data/time.htm) {Working with time series}
set url(examples/index.htm) {Example Models}
set url(examples/forest.htm) {Forest tree growth}
set url(examples/control.htm) {Process control}
set url(examples/supply.htm) {Supply and demand}
