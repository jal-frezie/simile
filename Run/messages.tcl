set msgs(compartment) "Add compartments to the model"
set msgs(flow) "Add flows to/from model compartments"
set msgs(variable) "Add variables to the model"
set msgs(influence) "Add influences between components"
set msgs(submodel) "Add new submodels to the model"
set msgs(relation) "Connect submodels playing roles in a relationship to a relation submodel"
set msgs(condition) "Add conditions for the existence of submodel instances"
set msgs(creation) "Add creation processes to population submodels"
set msgs(immigration) "Add immigration processes to population submodels"
set msgs(reproduction) "Add reproduction processes to population submodels"
set msgs(loss) "Add loss processes to population submodels"
set msgs(move) "Move components around the diagram"
set msgs(copy) "Make copies of submodels"
set msgs(ghost) "Create 'ghosts' of components with values"
set msgs(select) "Click to edit a component's caption or doubleclick to edit its contents"
set msgs(delete) "Delete components"
set msgs(rerun) "Start running the model again, rebuilding it if it has changed"
set msgs(undo) "Undo recent operations sequentially (up to 32)"
set msgs(redo) "Redo operations that were undone"
set msgs(customize) "Customize appearance of components (first select type to customize from top row)"
set msgs(find) "Find a component in this window whose caption matches some text"
set msgs(findmore) "Find more components with captions matching the same text"
set msgs(exit) "Exit SIMILE"

set msgs(sum) "Result is the sum of all elements of the argument"
set msgs(product) "Result is the product of all elements of the argument"
set msgs(place_in) "When making an array with makearay, this gives each term's position in the array -- argument is nesting depth"
set msgs(count) "Number of values in the argument"
set msgs(any) "Result is true if any of the argument elements are true"
set msgs(all) "Result is true if all of the argument elements are true"
set msgs(parent) "Returns the id of the individual whose reproduction gave rise to this one, or 0 if it immigrated or was created"
set msgs(init_time) "Returns the time at which this instance appeared -- argument is dummy"
set msgs(time) "Returns the current time  -- argument is dummy"
set msgs(dt) "Returns the duration of the time step specified by the argument"
set msgs(prev) "Returns the value of this component the given number of time steps ago"
set msgs(makearray) "Makes an array of the given number of values from the first argument"
set msgs(element) "Picks a value from an array according to the second argument"
set msgs(size) "Takes the name of a fixed-membership submodel and if one arg, returns its number of instances or if two, the size of one of its dimensions"
set msgs(least) "Returns the smallest value from an array/list of values"
set msgs(greatest) "Returns the largest value from an array/list of values"
set msgs(colin) "Takes as its one argument an array/list of n scalar elements and returns a random integer between 1 and n with probability proportional to the corresponding elements in the input array/list, calculating a new value each local time step."
set msgs(abs) "Returns absolute difference between argument and zero"
set msgs(ceil) "Rounds argument up to a whole number"
set msgs(floor) "Rounds argument down to a whole number"
set msgs(channel_is) "Arg is an immigration, reproduction or creation channel. Returns true if this individual appeared through that channel."
set msgs(choose) "choose(a,b,c) is shorthand for 'if a then b else c'"
set msgs(exp) "Returns e to the power of a number"
set msgs(fmod) "Returns remainder after dividing first argument by second"
set msgs(hypot) "Returns length of hypotenuse of triangle with given base and height"
set msgs(int) "Returns integer part of argument"
set msgs(last) "Recalls value of argument from last time step"
set msgs(log) "Returns natural logarithm of argument"
set msgs(log10) "Returns base-10 logarithm of argument"
set msgs(max) "Returns greater of two values"
set msgs(min) "Returns lesser of two values"
set msgs(pow) "Returns first number to the power of the second"
set msgs(rand_var) "Returns a random number between the two bounds, with a new value every time step"
set msgs(rand_const) "Returns a random number between the two bounds, which stays the same until reset"
set msgs(sqrt) "Returns the square root of the argument. Calling this with a negative argument when running a model in Tcl under a version of Windows other than 95 original on an Intel Celeron processor can lead to mysterious crashes in Microsoft Office applications, especially early in the tax year."

set msgs(initToolbar) "This decides whether the toolbar \
	(the first line of buttons below the menus) is displayed in the \
	desktop window when the application is started, and in new \
	submodel windows if they are large enough."
set msgs(initNavbar) "This decides whether the navigation bar \
	(the second line of buttons below the menus) is displayed in the \
	desktop window when the application is started, and in new \
	submodel windows if they are large enough."
set msgs(desktopDetail) "Sets the initial number of \
	submodel levels to display. This can be changed later with the \
	Window -> Display detail -> Submodels and Relations menu item."
set msgs(maxWinWidth) "Maximum width of a window, prevents new windows for \
	complex submodels coming up huge. Maximum height is 3/4 of this."
set msgs(compChoice) "Models can be compiled and linked \
	using either Microsoft Visual C++ (any 32-bit version) or GNU \
	mingw GCC (version 2.95.2 or later)."
set msgs(compDescPop) "While in pointer mode, holding the pointer over any \
	model component will cause a popup window to appear including that \
	component's equation or properties."
set msgs(compValPop) "While in pointer mode, if the model is running, holding \
	the pointer over any model component will cause a popup window to \
	appear including that component's current value(s) or instance \
	indices."
set msgs(compCmtPop) "While in pointer mode, holding \
	the pointer over any model component will cause a popup window to \
	appear including that component's description and comment text."
set msgs(recentCount) "This is the number of previously opened models that \
	will appear as reopen options in the File menu."
set msgs(flowRouting) "Setting this causes flows to be drawn as a series of \
	horizontal or vertical segments. If it is off, they will be drawn \
	directly from their source to their destination."
set msgs(deleteEndToEnd) "If this is selected, deleting a link section will \
	remove other sections leading to or from it. Otherwise an input \
variable will be made at the start of the next section."
set msgs(helperManager) "Use the single window Run Time Environement to manange \
       displays and controls."
set geometryXYexplanation "Position of the window, when not using the single \
        window Run Time Environment, in the form xy, x and y specify \
        the desired location of window on the screen, in pixels. \
        x and y must be preceeded by + or - . If x is preceded by +, \
            it specifies the number of pixels between the left edge \
            of the screen and the left edge of window's border;  \
            if preceded by - then x specifies the number of pixels \
            between the right edge of the screen and the right edge \
            of window's border.  If y is preceded by + then it \
            specifies the number of pixels between the top of the \
            screen and the top of window's border;  if y is \
            preceded by - then it specifies the number of pixels \
            between the bottom of window's border and the bottom \
            of the screen. For instance, \"+100-100\" would place the window \
	    a short way in from the bottom left corner. \"default\" means \
	    use the window manager\'s placement algorithm."
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
