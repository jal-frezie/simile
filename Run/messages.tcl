# Simile source code file: Run/messages.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file is sourced by toolbox.tcl, providing definitions of popup help text
# and links to help file pages.
#
# prepositions etc
set msgs(in) [tr. in]
set msgs(out) [tr. out]

# simile basics -- objects
set msgs(relation) [tr. {relation}]
set msgs(flow) [tr. {flow}]
set msgs(influence) [tr. {influence}]
set msgs(model) [tr. {Simile model}]
set msgs(unsaved) [tr. {unsaved}]

# abbreviations for default component names, e.g., compartment -> comp, so 1st
# compartment gets default name of comp1
set msgs(compartment_abbrev) [tr. {comp}]
set msgs(function_abbrev) [tr. {fn}]
set msgs(variable_abbrev) [tr. {var}]
set msgs(cloud_abbrev) [tr. {cd}]
set msgs(submodel_abbrev) [tr. {submodel}]
set msgs(condition_abbrev) [tr. {cond}]
set msgs(alarm_abbrev) [tr. {al}]
set msgs(creation_abbrev) [tr. {cr}]
set msgs(immigration_abbrev) [tr. {im}]
set msgs(reproduction_abbrev) [tr. {rep}]
set msgs(loss_abbrev) [tr. {loss}]
set msgs(event_abbrev) [tr. {event}]
set msgs(squirt_abbrev) [tr. {sqt}]
set msgs(state_abbrev) [tr. {state}]
set msgs(text_abbrev) [tr. {text}]
set msgs(flow_abbrev) [tr. {flow}]
set msgs(influence_abbrev) [tr. {i}]
set msgs(relation_abbrev) [tr. {role}]
set msgs(border_abbrev) [tr. {bdr}]
set msgs(desktop_abbrev) [tr. {Desktop}]
set msgs(fragment_abbrev) [tr. {frag}]

# simile basics -- actions
set msgs(reroute) [tr. {Reroute}]
set msgs(delete) [tr. {Delete}]
set msgs(cut) [tr. {Cut}]
set msgs(copy) [tr. {Copy}]
set msgs() [tr. {}]

# simile basics -- for eqn dialogue
set msgs(equation_for) [tr. {Equation for %1$s}]
set msgs(init_val_for) [tr. {Initial value for %1$s}]
set msgs(cause_for) [tr. {Cause for %1$s}]
set msgs(rules_for) [tr. {Rules for %1$s}]
set msgs(param) [tr. {Parameter}]
set msgs(in_units) [tr. {In units}]
set msgs(ip_name) [tr. {input parameter name}]
set msgs(minval) [tr. {Min. value}]
set msgs(maxval) [tr. {Max. value}]
set msgs(exp_inter) [tr. {explicit intermediate result}]
set msgs() [tr. {}]

# popup messages
set msgs(add_compartment) [tr. {Add compartments}]
set msgs(add_flow) [tr. {Add flows}]
set msgs(add_variable) [tr. {Add variables}]
set msgs(add_influence) [tr. {Add influences}]
set msgs(add_submodel) [tr. {Add new submodels}]
set msgs(add_relation) [tr. {Connect submodels playing roles in a relationship to a relation submodel}]
set msgs(add_condition) [tr. {Add conditions for the existence of submodel instances}]
set msgs(add_alarm) [tr. {Add conditions for ending calculations within a submodel instance}]
set msgs(add_text) [tr. {Add a text box to display additional information}]
set msgs(add_creation) [tr. {Add creation processes to population submodels}]
set msgs(add_immigration) [tr. {Add immigration processes to population submodels}]
set msgs(add_reproduction) [tr. {Add reproduction processes to population submodels}]
set msgs(add_loss) [tr. {Add destruction processes to population submodels}]
set msgs(move) [tr. {Move diagram}]
set msgs(copy) [tr. {Make copies of submodels}]
set msgs(ghost) [tr. {Create 'ghosts' of components}]
set msgs(select) [tr. {Select components}]
set msgs(delete) [tr. {Delete components}]
set msgs(rerun) [tr. {Run the model, building it if necessary}]
set msgs(undo) [tr. {Undo operations sequentially}]
set msgs(redo) [tr. {Redo operations that were undone}]
set msgs(customize) [tr. {Customize appearance of components (first select type to customize from top row)}]
set msgs(find) [tr. {Find a component}]
set msgs(findmore) [tr. {Find more components}]
set msgs(exit) [tr. {Exit Simile}]
set msgs(runenv) [tr. {Go to the Run Environment window}]
set msgs(snap) [tr. {Inspect model variable}]

set msgs(built-in) [tr. {Built-in functions of the Simile equation language}]
set msgs(arithmetic) [tr. {Arithmetic functions}]
set msgs(list_handling) [tr. {Functions for manipulating array or list data}]
set msgs(model_properties) [tr. {Functions that return information relating to the model components containing this equation}]
set msgs(statistics) [tr. {Statistical and stochastic functions}]
set msgs(trigonometry) [tr. {Trigonometrival functions}]
set msgs(et_top_level) [tr. {Enumerated type names and members}]
set msgs(sum) [tr. {Returns the sum of all elements of the argument}]
set msgs(product) [tr. {Returns the product of all elements of the argument}]
set msgs(place_in) [tr. {Returns each term's position, when making an array with makearay -- argument is nesting depth}]
set msgs(count) [tr. {Returns the number of values in the argument}]
set msgs(any) [tr. {Returns true if any of the argument elements are true}]
set msgs(all) [tr. {Returns true if all of the argument elements are true}]
set msgs(subtotals) [tr. {Returns an array with the cumulative totals of the values in the argument array. Element n of the result is the sum of argument elements 1 through n.}]
set msgs(rankings) [tr. {Returns an array with the ranks of the corresponding elements in the argument. This is 1 for the largest element, and equal to the size of the array for the smallest.}]
set msgs(colin) [tr. {Returns a random integer corresponding to an element of the argument array, with the probability of each value proportional to the value of that element}]
set msgs(posgreatest) [tr. {returns the position of the highest value in the argument array, or the position of the first element with the highest value if there are more than one with that value}]
set msgs(posleast) [tr. {returns the position of the lowest value in the argument array, or the position of the first element with the lowest value if there are more than one with that value}]
set msgs(firsttrue) [tr. {Takes an array of booleans and returns the index of the first with value "true"}]
set msgs(howmanytrue) [tr. {Takes an array of booleans and returns the number that are true}]
set msgs(parent) [tr. {Returns the index of the instance from which this one was reproduced, or 0 if this one was created or immigrated}]
set msgs(init_time) [tr. {Returns the time at which this instance appeared -- argument is dummy}]
set msgs(at_init) [tr. {Returns the value the argument had when first used, i.e., on model reset or when the submodel instance containing this equation was created}]
set msgs(default) [tr. {Utility for writing type-independent macros; returns 0 if arg is number, "false" if arg is boolean, or first member of arg's enumerated type}]
set msgs(time) [tr. {Returns the current time, to nearest multiple of the time step specified by the argument -- none means that of current submodel}]
set msgs(dt) [tr. {Returns the duration of the time step specified by the argument -- none means that of current submodel}]
set msgs(prev) [tr. {Returns the value of this component the given number of time steps ago}]
set msgs(makearray) [tr. {Returns an array of the given number of values from the first argument}]
set msgs(element) [tr. {Returns a value from an array according to the second argument}]
set msgs(first) [tr. {Returns "true" if argument is either the first member of its enumerated type or the integer 1}]
set msgs(following) [tr. {Returns the enumerated type member that comes after its argument, or the argument plus one if it is an integer}]
set msgs(index) [tr. {Returns the index of the containing submodel instance at the given number of nesting levels}]
set msgs(preceding) [tr. {Returns the enumerated type member that comes before its argument, or the argument minus one if it is an integer}]
set msgs(size) [tr. {Takes the name of a fixed-membership submodel and if one arg, returns its number of instances or if two, the size of one of its dimensions}]
set msgs(stop) [tr. {If this gets executed, the model stops and displays a message including the argument. Use in a conditional statement to detect when things are going wrong.}]
set msgs(const_delay) [tr. {Returns the first argument delayed by the time given in the second argument, which must be a numeric value. Resolution is 0.1 day.}]
set msgs(var_delay) [tr. {Returns the first argument delayed by the time given in the second argument, which can be an expression. Resolution is 0.1 day and max delay is 100 days.}]
set msgs(least) [tr. {Returns the smallest value from an array/list of values}]
set msgs(greatest) [tr. {Returns the largest value from an array/list of values}]
set msgs(with_least) [tr. {Takes two arrays or lists with equal size, and returns the element of the second that corresponds to the element of the first with the smallest value.}]
set msgs(with_greatest) [tr. {Takes two arrays or lists with equal size, and returns the element of the second that corresponds to the element of the first with the largest value.}]
set msgs(with_colin) [tr. {Takes two lists with equal size, and returns an element from the second argument, picked at random with the probability of each element proportional to the value of the corresponding element in the first argument.}]
set msgs(abs) [tr. {Returns absolute difference between argument and zero}]
set msgs(ceil) [tr. {Rounds argument up to a whole number}]
set msgs(floor) [tr. {Rounds argument down to a whole number}]
set msgs(channel_is) [tr. {Argument is an immigration, reproduction or creation channel. Returns true if this individual appeared through that channel.}]
set msgs(is_new_instance) [tr. {Returns TRUE if the submodel instance containing the component was created on the most recent time step. TRUE everywhere after reset.}]
set msgs(dies_of) [tr. {Argument is a mortality channel. Returns true if this channel will cause the individual to disappear at the end of the current time step.}]
set msgs(latency) [tr. {Argument is an immigration or reproduction channel. Returns the fraction indicating how near that channel is to producing another individual. When it reaches 1 the individual appears and it goes back to 0.}]
set msgs(choose) [tr. {choose(a,b,c) is shorthand for 'if a then b else c'}]
set msgs(exp) [tr. {Returns e to the power of a number}]
set msgs(fmod) [tr. {Returns remainder after dividing first argument by second}]
set msgs(hypot) [tr. {Returns length of hypotenuse of triangle with given base and height}]
set msgs(atan2) {atan2(y x): Returns the angle to the baseline of the line from the origin to [x,y], ranging from -pi to pi}
set msgs(int) [tr. {Returns integer part of argument}]
set msgs(last) [tr. {Returns value of argument from last time step}]
set msgs(in_preceding) [tr. {Returns value of argument in the preceding submodel instance, or 0 in first instance}]
set msgs(in_progenitor) [tr. {Returns value of argument in the individual from which this one was reproduced, or 0 if this one was created or immigrated. Behaviour undefined (and can crash model) if this individual is an orphan; if this is a possibility, use at_init(in_progenitor(exp)) so progenitor exists when it is evaluated.}]
set msgs(log) [tr. {Returns natural logarithm of argument}]
set msgs(log10) [tr. {Returns base-10 logarithm of argument}]
set msgs(max) [tr. {Returns greater of two values}]
set msgs(min) [tr. {Returns lesser of two values}]
set msgs(pow) [tr. {Returns first argument to the power of the second}]
set msgs(round) [tr. {Returns the closest whole number to its argument}]
set msgs(rand_var) [tr. {Returns a random number between the two arguments, with a new value every time step}]
set msgs(rand_const) [tr. {Returns a random number between the two arguments, which stays the same until reset}]
set msgs(sqrt) [tr. {Returns the square root of the argument. Calling this with a negative argument when running a model in Tcl under a version of Windows other than 95 original on an Intel Celeron processor can lead to mysterious crashes in Microsoft Office applications, especially early in the tax year.}]
set msgs(gaussian_var) [tr. {gaussian_var(mean sd): returns values from a gaussian distribution with 
        the given mean (mean) and standard deviation (sd).}]
set msgs(poidev) [tr. {poidev(mean): returns values from a Poisson distribution with the given mean (mean).}]
set msgs(binome) [tr. {binome(prob n): returns values from a binomial distribution resulting from n trials each of probability prob.}]
set msgs(hypergeom) [tr. {hypergeom(pop mark sample): Returns random samples from a hypergeometric distribution, i.e., the number of positives drawing 'sample' individuals from a population of 'pop' containing 'marked' positives.}]
set msgs(sgn) [tr. {sgn(r): returns the sign of r, -1 if negative or 1 if positive}]
set msgs(winPosn) [tr. {Choose placement of initial model window when Simile starts.}]
set msgs(initToolbar) [tr. {Display component bar in the desktop window when Simile starts, and in new submodel windows if they are large enough.}]
set msgs(initNavbar) [tr. {Display tool bar in the desktop window when Simile starts, and in new submodel windows if they are large enough.}]
set msgs(initEqnbar) [tr. {Display equation bar in the desktop window when Simile starts, and in new submodel windows if they are large enough.}]
set msgs(initGrid) [tr. {Display placement grid in new model windows.}]
set msgs(gridH) [tr. {Spacing in pixels between vertical grid lines.}]
set msgs(gridV) [tr. {Spacing in pixels between horizontal grid lines.}]
set msgs(gridD) [tr. {Adjusts visual prominence of grid lines.}]
set msgs(bigButtons) [tr. {Use alternative (larger) buttons for the tool bar and component bar.}]
set msgs(popupHelp) [tr. {Display tooltips when hovering over tool bar and component bar buttons.}]
set msgs(gridSnap) [tr. {When adding or moving components, keep them centred on a grid intersection, to keep the diagram neat.}]
set msgs(quickDrag) [tr. {When moving the selection, do not update the routes of links going to or from it or check if the current location is free of overlaps until finishing the move. This makes dragging easier for very large selections.}]
set msgs(myButton) [tr. {Text entered here can be added to equations using a button near the top right of the equation dialogue keypad.}]
set msgs(desktopDetail) [tr. {Sets the initial number of submodel levels to display. This can be changed later with the Window -> Display detail -> Submodels and Relations menu item.}]
set msgs(maxWinWidth) [tr. {Maximum width of a window, prevents new windows for complex submodels coming up huge. Maximum height is 3/4 of this.}]
set msgs(compChoice) [tr. {Default is gcc/g++ included in Simile distribution. Others must be installed on your system before you can use them.}]
set msgs(compDescPop) [tr. {Enable popups for component's equation and description when pointer hovers on component.}]
set msgs(compValPop) [tr. {Enable popups for component's current value(s) or instance indices when pointer hovers on component.}]
set msgs(compCmtPop) [tr. {Enable popups for component's comment text when pointer hovers on component.}]
set msgs(eqListWhere) [tr. {Include information about the origins of each equation's input parameters in the equation listing}]
set msgs(eqListETDefns) [tr. {Include names and members of enumerated types defined in each submodel in the equation listing}]
set msgs(eqListComments) [tr. {Include comments in the equation listing}]
set msgs(ncfv) [tr. {No comment for value}]
set msgs(recentCount) [tr. {Save names of recently opened models for display on the File menu.}]
set msgs(saveExtras) [tr. {Save the canvas file to reduce the time initially taken to draw the model diagram.}]
set msgs(quickExit) [tr. {Choose an option to be offered in a short query when closing a window with unsaved content -- "None" goes straight to full query}]
set msgs(flowRouting) [tr. {Draw flows as a series of horizontal or vertical segments.}]
set msgs(infRouting) [tr. {Curvature of influence arrows (degrees to right)}]
set msgs(roleRouting) [tr. {Curvature of role arrows (degrees to right)}]
set msgs(deleteEndToEnd) [tr. {Select or unselect all sections of multi-section influences, relations or flows as if they were a single component.}]
set msgs(defBackground) [tr. {Choose whether the background of a new submodel hides the background of its parent model.}]
set msgs(hackBreak) [tr. {Display a dialogue when the model code is about to be compiled, allowing it to be inspected or modified first. Selecting this option also causes some other dialogues with status information to be displayed.}]
set msgs(popupPrecision) [tr. {Number of significant figures displayed when real values are shown in popups, or 0 for default.}]
set msgs(snapPrecision) [tr. {Number of significant figures displayed when real values are shown in snapshot windows, or 0 for default.}]
set msgs(helperManager) [tr. {Use single window to manange run time displays and controls.}]

# for equation listings
set msgs(list_assoc_sm) [tr. {Submodel "%1$s" an association submodel between "%2$s" (in role "%3$s") and "%4$s" (in role "%5$s").}]
set msgs(list_selfassoc_sm) [tr. {Submodel "%1$s" is an association submodel between "%2$s" and itself with roles "%3$s" and "%4$s".}]
set msgs(list_satellite_sm) [tr. {Submodel "%1$s" is a "%2$s" satellite of submodel "%3$s".}]
set msgs(list_by_record_sm) [tr. {Submodel "%1$s" is a membership by record submodel.}]
set msgs(list_pop_sm) [tr. {Submodel "%1$s" is a population submodel.}]
set msgs(list_cond_sm) [tr. {Submodel "%1$s" is a conditional fixed membership submodel of dimensions %2$s.}]
set msgs(list_unicond_sm) [tr. {Submodel "%1$s" is a conditional submodel.}]
set msgs(list_multi_sm) [tr. {Submodel "%1$s" is a fixed_membership multi-instance submodel with dimensions %2$s.}]

# window headings
set msgs(props_title) [tr. {Properties of "%1$s" - Simile}]
set msgs(exec_title) [tr. {Execution of "%1$s" - Simile}]

# checkbuttons in link properties
set msgs(use_sofar) [tr. {Use destination values made in same time step}]
set msgs(exclusive) [tr. {Exclusive role}]
set msgs(can_lookup) [tr. {Allow base instance lookup}]
set msgs(without_role) [tr. {Include array/list of all source values}]
set msgs(up_hierarchy) [tr. {Include array of values from all this submodel's instances}]
set msgs(in_8_nbrs) [tr. {Include list of values from up to 8 grid squares sharing a side or corner with current square}]
set msgs(in_6_nbrs) [tr. {Include list of values from up to 6 grid hexagons sharing a side with the current hexagon}]
set msgs(in_offspring) [tr. {Include list of values from individuals which are the offspring of the current individual via any reproduction channel}]
set msgs(with_role) [tr. {Include source value(s) corresponding with role "%1$s"}]

# parameter sources
set msgs(metafile_ref) [tr. {Loaded from file "%1$s" according to reference in file "%2$s"}]
set msgs(metafile_lit) [tr. {Literal data in "%1$s"}]
set msgs(metafile_bin) [tr. {Binary data in "%1$s"}]
set msgs(direct_ref) [tr. {Loaded from file "%1$s"}]

# file read/write operations
set msgs(reading_file) [tr. {Reading information from file}]

set msgs(pl_convert_from) [tr. {Converting from Simile version %1$s model representation}]
set msgs(pl_convert_to) [tr. {Converting to Simile version %1$s model representation}]
set msgs(writing_root) [tr. {Writing root information}]
set msgs(writing_node) [tr. {Writing node information}]
set msgs(writing_arc) [tr. {Writing arc information}]
set msgs(updating_v) [tr. {Updating pre-Simile version %1$s model representation}]
set msgs(pl_coord) [tr. {Co-ordinating model information}]
set msgs(decode_mime) [tr. {Decoding MIME-format saved file}]
set msgs(translate_cnv) [tr. {Translating internal IDs of canvas objects.}]
set msgs(write_interface) [tr. {Listing all %1$ss going %2$sside the model}]
# (1st parameter is component type, 2nd is translation of 'in' or 'out')
set msgs(pl_action) [tr. {%1$s in progress}]
set msgs(pl_selall) [tr. {Selecting whole model}]
set msgs(pl_unselall) [tr. {Unselecting whole model}]
set msgs(pl_invsel) [tr. {Inverting selection}]
set msgs(pl_refatten) [tr. {Changing relative scale of submodel}]
set msgs(pl_trimin) [tr. {Creating new inputs for values from deleted submodel}]
set msgs(pl_draw) [tr. {Updating screen representation of components affected by this delete}]
set msgs(pl_mimeout) [tr. {Creating MIME-format saved file}]
set msgs(save_cnv) [tr. {Saving canvas description}]

# stages in model build process
set msgs(pl_check) [tr. {Checking that the model is complete and consistent}]
set msgs(pl_inst) [tr. {Instantiating expressions from node values}]
set msgs(pl_comp) [tr. {Compiling the program generated for the model}]
set msgs(pl_name) [tr. {Choosing names for program variables}]
set msgs(pl_expr) [tr. {Creating submodel value expressions}]
set msgs(pl_const) [tr. {Generating constant declarations}]
set msgs(pl_struct) [tr. {Generating structure declarations}]
set msgs(pl_meta) [tr. {Generating metadata declarations}]
set msgs(pl_sort) [tr. {Sorting assignments into correct time steps}]
set msgs(pl_loop) [tr. {Checking consistency of same-time-step loops}]
set msgs(pl_order) [tr. {Ordering model execution assignments}]
set msgs(pl_code) [tr. {Generating code for model execution}]
set msgs(pl_xref) [tr. {Cross-referencing effects and conditions}]
set msgs(pl_locn) [tr. {Doing submodel %1$s, level %2$s}]

set msgs(prolog_ref_fail) [tr. {This operation cannot proceed because the program failed to find a %1$s called %2$s}]
# arg 1 is a component, e.g., submodel
set msgs(prolog_misparse) [tr. {Attempting to decipher this item failed, generating this diagnostic message: 
"%1$s"
This is what was read in, with the text <HERE> inserted at the point where the problem was found:

%2$s <HERE> %3$s}]
set msgs(prolog_bug) [tr. {Unexpected Prolog error message: "%1$s"}]

set msgs(start_fail_title) [tr. {Simile has been unable to start up due to problems with this system.}]
set msgs(start_fail_message) [tr. {The following system error message was generated:
%1$s}]

set msgs(user_fn_misparse_title) [tr. {Parsing definitions in %1$s}]
set msgs(user_fn_misparse_message) [tr. {Error parsing user-defined macros and functions in %1$s}]
set msgs(user_fn_misparse_detail) {%2$s}

set msgs(unused_macro_param_title) [tr. {Parsing definitions in %1$s}]
set msgs(unused_macro_param_message) [tr. {Failed to parse macro definition:
%1$s
The macro function contains the parameter "%2$s", which does not appear in the arguments of the macro template}]

set msgs(bad_user_fn_format_title) [tr. {Parsing definitions in %1$s}]
set msgs(bad_user_fn_format_message) [tr. {The file %1$s contained the line %2$s which is in the wrong format for a macro, function or unit definition -- please refer to the documentation.}]
set msgs(bad_user_fn_format_full) [tr. {It appears that the functor in this line is "%3$s" and the arguments are %4$s.}]

set msgs(bust_edition_limit_title) [tr. {Problem loading model}]
set msgs(bust_edition_limit_message) [tr. {Loading this model makes %1$d equations. This is greater than %2$d, and it was not created by the enterprise edition, so it cannot be loaded in the %3$s edition.}]
set msgs(bust_edition_limit_detail) [tr. {To upgrade, go to simulistics.com}]

set msgs(save_edition_limit_title) [tr. {Problem saving model}]
set msgs(save_edition_limit_message) [tr. {This model has %1$s equations. This is greater than %2$s, so it cannot be saved in the %3$s edition.}]
set msgs(save_edition_limit_detail) [tr. {To upgrade, go to simulistics.com}]

set msgs(future_shock_title) [tr. {Future shock!}]
set msgs(future_shock_message) [tr. {This file was created with a later version of Simile than the one you are currently running.}]
set msgs(future_shock_detail) [tr. {To avoid potential problems, please update your copy to version %1$s or later.}]

set msgs(declaration_misparse_title) [tr. {Problem loading model}]
set msgs(declaration_misparse_message) [tr. {A line in your model file could not be parsed.}]
set msgs(declaration_misparse_detail) [tr. {This may be due to more careful checking of the syntax in recent versions of Simile. If you choose to continue (see all), and the model fails to run as expected, please contact your software supplier, quoting the full message.}]
set msgs(declaration_misparse_full) [tr. {The syntax error was:
%1$s}]

set msgs(lost_component_title) [tr. {Problem loading model}]
set msgs(lost_component_message) [tr. {Component %1$s missing. The following lines in the file contained references to model components that were not found: %2$s}]

set msgs(bad_model_format_title) [tr. {Problem loading model}]
set msgs(bad_model_format_message) [tr. {Simile had some sort of problem incorporating the following lines from the file into the model: %1$s}]
set msgs(bad_model_format_detail) [tr. {Although this data parses correctly, it does not make sense as part of a model specification in Simile's internal representation.}]

set msgs(web_fail_title) [tr. {Problem connecting to server}]
set msgs(web_fail_message) [tr. {Communication with a web service is required but cannot be established. Is there a connection to the internet?}]
set msgs(web_fail_full) [tr. {The web access command returned the following exception: "%1$s"}]
set msgs(xml_trade_fail_title) [tr. {Bad XML model description}]
set msgs(xml_trade_fail_message) [tr. {The Webflow service failed to convert this file between an XML model description and a set of Prolog-format model declarations. Please try using the service via your browser to see a full error diagnosis.}]
set msgs(linuxPrintFail_title) [tr. {Print command result}]
set msgs(linuxPrintFail_message) [tr. {Printing seems to have failed.}]
set msgs(linuxPrintFail_detail) [tr. {The result returned by the print command was:

%1$s}]
set msgs(linuxPrintFail_full) [tr. {Please see the online help to find out more about setting up printing from Simile. Alternatively you can export the model diagram as a PostScript file (use the File...Export menu command) and then print that using another package.}]

set msgs(map_failure_title) [tr. {Conversion failure}]
set msgs(map_failure_message) [tr. {Failed to convert %1$s between Prolog-rendered XML object %3$s and Simile model description clause %2$s}]

set msgs(overlap_title) [tr. {Failed to %1$s %2$s}]
set msgs(overlap_message) [tr. {Cannot %1$s %2$s here due to overlaps.}]
set msgs(overlap_full) [tr. {You can increase the amount of space available by reducing the "Relative scale" value in the Advanced section of the desktop or submodel properties.}]

set msgs(abandon_title) [tr. {Save changes}]
set msgs(abandon_message) [tr. {The current version of %1$s (in %2$s) has not been saved. Leave anyway?}]
set msgs(abandon_full) [tr. {If you don't save, the changes made in this session will be lost.}]

set msgs(open_model_failed_title) [tr. {Failed to open model}]
set msgs(open_model_failed_message) [tr. {Simile could not open this file as a model.}]
set msgs(open_model_failed_detail) [tr. {It should be a model file or declaration list saved by Simile.}]
set msgs(open_model_failed_full) [tr. {This file could not be read as a MIME because: %1$s. It could not be read as a model description because: %2$s.}]

set msgs(flow_splits_at_border_title) [tr. {Problem with flow}]
set msgs(flow_splits_at_border_message) [tr. {Flow %1$s cannot connect to compartment %2$s because its value would be split where it crosses the border of submodel %3$s}]

set msgs(no_caption_match_title) [tr. {Submodel name mismatch}]
set msgs(no_caption_match_message) [tr. {The interface specification you have chosen is for a submodel named %1$s, whereas the current submodel is named %2$s. Do you want the submodel renamed?}]

set msgs(remove_orphan_title) [tr. {Correcting model inconsistency}]
set msgs(remove_orphan_message) [tr. {Removing orphan node %1$s from submodel %2$s.}]

set msgs(compile_failed_title) [tr. {Problem during compilation}]
set msgs(compile_failed_message) [tr. {The compiler raised a problem with the code generated for this model.}]
set msgs(compile_failed_detail) [tr. {It may help to try the 'Debug' option.}]
set msgs(compile_failed_full) [tr. {The error was: %1$s.}]

set msgs(link_inconsistency_title) [tr. {Problem with model}]
set msgs(link_inconsistency_message) [tr. {This model cannot be built because ot contains an inconsistent link equivalence: %1$s.}]
set msgs(link_inconsistency_detail) [tr. {Please report this problem to your software supplier.}]

set msgs(unspecified_title) [tr. {Model is incomplete}]
set msgs(unspecified_message) [tr. {Submodel "%1$s" contains incomplete component: "%2$s"}]
set msgs(unspecified_detail) [tr. {This component is shown in red, which means it has not been fully specified.}]
set msgs(unspecified_full) [tr. {Edit the equation of this component, or make it a file parameter.}]

set msgs(no_defining_param_title) [tr. {Required component missing}]
set msgs(no_defining_param_message) [tr. {The membership of submodel "%1$s" is set by the number of values supplied for its fixed parameters, but it has no fixed parameters.}]

set msgs(no_seed_param_title) [tr. {Required component missing}]
set msgs(no_seed_param_message) [tr. {The membership of submodel "%1$s" is set by the population channel symbols it contains. In order that the population have some members, it must contain at least one creation or immigration symbol, and it does not contain any.}]

set msgs(misplaced_channel_title) [tr. {Component in wrong place}]
set msgs(misplaced_channel_message) [tr. {The component "%1$s" is a channel, which only has meaning if its parent is a population submodel, which submodel "%2$s" is not.}]

set msgs(missing_function_title) [tr. {User-defined function missing}]
set msgs(missing_function_message) [tr. {This model cannot be built because it contains the user-defined function %1$s}]
set msgs(missing_function_detail) [tr. {%1$s should have a definition in the file %2$s, but this file is missing.}]

set msgs(no_such_function_title) [tr. {Non-existent function used}]
set msgs(no_such_function_message) [tr. {Attempting to process subexpression "%1$s": Simile does not include "%2$s" as a function.}]

set msgs(tail_not_list_title) [tr. {Misuse of Prolog operator}]
set msgs(tail_not_list_message) [tr. {The Prolog list operators "." and "|" may only be used if the second argument is an explicit list, which is not the case in "%1$s".}]

set msgs(wrong_format_of_args_title) [tr. {Wrong format of args}]
set msgs(wrong_format_of_args_message) [tr. {Attempting to process subexpression "%1$s": You have tried to use the macro or function "%2$s" with arguments "%3$s", but it must take arguments of the form "%4$s".}]
set msgs(wrong_format_of_args_detail) [tr. {This problem might be fixed by adding parentheses around a subexpression that forms an argument of this subexpression.}]

set msgs(wrong_no_of_args_title) [tr. {Wrong number of args}]
set msgs(wrong_no_of_args_message) [tr. {Attempting to process subexpression "%1$s": You have tried to use the %2$s function "%3$s" with %4$s arguments, but it must take %5$s}]

set msgs(missing_graph_or_table_data_title) [tr. {Built-in data missing}]
set msgs(missing_graph_or_table_data_message) [tr. {Subexpression "%1$s" is a reference to a data table or sketch graph, but no data has been entered for it.}]
set msgs(missing_graph_or_table_data_detail) [tr. {Use the Graph and Table buttons in the equation dialogue to add these functions and define data for them.}]

set msgs(cannot_combine_argument_dimensions_title) [tr. {Argument dimensions incompatible}]
set msgs(cannot_combine_argument_dimensions_message) [tr. {Simile cannot work out what dimensions the result of "%1$s" should have -- the dimensions of the arguments are incompatible.}]

set msgs(no_preceding_instance_title) [tr. {Function has no value here}]
set msgs(no_preceding_instance_message) [tr. {This equation uses the "in_preceding(...)" function, but the component is not inside any multi-instance submodel so there is no preceding instance.}]

set msgs(mismatched_units_title) [tr. {Argument types incompatible}]
set msgs(mismatched_units_message) [tr. {The arguments of the function "%1$s" in the term "%2$s" have the following types: %3$s. These cannot be matched to the expected argument types for this function, which are %4$s.}]

set msgs(mixed_trigger_units_title) [tr. {Trigger types incompatible}]
set msgs(mixed_trigger_units_message) [tr. {The events that trigger the derived event "%1$s" have the following types: %2$s. These cannot be combined to produce a trigger magnitude that can be used in the event's equation.}]

set msgs(cannot_set_dims_title) [tr. {Not enough info}]
set msgs(cannot_set_dims_message) [tr. {The equation does not provide enough information to allow the size of dimension %1$s of explicit intermediate result %2$s to be determined.}]

set msgs(unused_inter_title) [tr. {Unused intermediate result}]
set msgs(unused_inter_message) [tr. {The equation is badly formed because it creates the explicit intermediate result %1$s, which is not subsequently used.}]

set msgs(parameter_name_reused_title) [tr. {Problem with intermediate result name}]
set msgs(parameter_name_reused_message) [tr. {The equation is badly formed because it creates the explicit intermediate result %1$s, which is also the name of an input parameter.}]

set msgs(parameter_name_recurs_title) [tr. {Problem with intermediate result name}]
set msgs(parameter_name_recurs_message) [tr. {The equation is badly formed because it creates the explicit intermediate result %1$s in the scope of an earlier explicit intermediate result with the same name.}]

set msgs(circular_evaluation_title) [tr. {Problem with model design}]
set msgs(circular_evaluation_message) [tr. {This model cannot be executed because it contains the following circular set(s) of function evaluations: %1$s}]

set msgs(ordering_failure_title) [tr. {Problem ordering calculations}]
set msgs(ordering_failure_message) [tr. {Failed to put this instruction into ordered sequence, despite it not seeming to depend on anything: %1$s}]
set msgs(ordering_failure_detail) [tr. {Please contact your software supplier.}]

set msgs(condition_outside_loop_title) [tr. {Problem with model design}]
set msgs(condition_outside_loop_message) [tr. {This model contains the target %1$s which depends on its own values from previous iterations of a program loop, which are used to make component %2$s. However the cycle of evaluations includes target %3$s, which is calculated outside the innermost program loop in which the values of %2$s are used by target %1$s}]

set msgs(undecipherable_operand_title) [tr. {Problem getting number}]
set msgs(undecipherable_operand_message) [tr. {%1$s does not stand for a number in the context of %2$s}]

set msgs(submodel_name_recurs_title) [tr. {Problem getting number}]
set msgs(submodel_name_recurs_message) [tr. {Cannot resolve reference to size of %1$s. There are multiple submodels of this name.}]

set msgs(no_such_dimension_title) [tr. {Problem getting number}]
set msgs(no_such_dimension_message) [tr. {Model "%1$s" does not have a dimension number %2$s}]

set msgs(not_single_fixed_dimension_title) [tr. {Problem getting number}]
set msgs(not_single_fixed_dimension_message) [tr. {Expression "%1$s" cannot be used as a single fixed value; its values are %2$s}]

set msgs(self_reference_title) [tr. {Problem getting number}]
set msgs(self_reference_message) [tr. {Self-reference to size of %1$s.}]

set msgs(absent_submodel_title) [tr. {Problem getting number}]
set msgs(absent_submodel_message) [tr. {Cannot resolve reference to size of %1$s. There is no submodel of this name.}]

set msgs(submodel_size_variable_title) [tr. {Problem getting number}]
set msgs(submodel_size_variable_message) [tr. {%1$s has a reference to a variable membership model in its dimensions.}]

set msgs(failed_ref_in_dimensions_title) [tr. {Problem with submodel dimensions}]
set msgs(failed_ref_in_dimensions_message) [tr. {The dimensions of submodel "%1$s" cannot be found, because it contains a reference to the size of submodel "%2$s", which cannot be resolved. This reference will be removed.}]

set msgs(dimensions_invalid_title) [tr. {Problem with submodel dimensions}]
set msgs(dimensions_invalid_message) [tr. {The dimensions of submodel "%1$s" cannot be found, because of a change elsewhere in the model. You should edit this submodel's properties to fix the problem.}]

set msgs(absent_enum_type_title) [tr. {Problem getting number}]
set msgs(absent_enum_type_message) [tr. {Cannot resolve reference to size of %1$s in component %2$s. There is no local enumerated type of this name.}]

set msgs(enum_type_mix_title) [tr. {Inconsistent type definitions}]
set msgs(enum_type_mix_message) [tr. {You cannot refer to the value of %1$s at this point because it depends on the enumerated type %2$s, which at that point has the definition %3$s but here has the definition %4$s}]

set msgs(param_in_vm_model_title) [tr. {Problem with model}]
set msgs(param_in_vm_model_message) [tr. {There is an external parameter, "%1$s", inside a variable-membership submodel, "%2$s."}]
set msgs(param_in_vm_model_detail) [tr. {This is not allowed, as the number of values in the file cannt change as the membership of the submodel does.}]
set msgs(param_in_vm_model_full) [tr. {Perhaps a per-record submodel, with its membership set by the number of records in the file, is needed here.}]

set msgs(lookup_not_allowed_title) [tr. {Problem with model}]
set msgs(lookup_not_allowed_message) [tr. {Submodel "%1$s" has a membership condition that looks up instances of the model at the base of role arrow "%2$s", but this role arrow does not have base instance lookup enabled.}]

set msgs(bad_instance_lookup_title) [tr. {Problem with model}]
set msgs(bad_instance_lookup_message) [tr. {This model includes an attempt to use base instance lookup for the association submodel "%1$s". This cannot be done because index(1) in this submodel is the index of a variable-membership submodel other than itself, and therefore not an array subscript.}]

set msgs(offer_restore_title) [tr. {Restore option}]
set msgs(offer_restore_message) [tr. {Simile left a log file of unsaved changes when this model was last edited.}]
set msgs(offer_restore_detail) [tr. {Ignore changes, or apply?}]
set msgs(offer_restore_full) [tr. {You can ignore these changes and edit the model as it was saved, or apply them to get back to where you were when Simile exited.}]

set msgs(no_autosave_title) [tr. {Autosave warning!}]
set msgs(no_autosave_message) [tr. {Could not create an autosave file called %1$s for this model.}]
set msgs(no_autosave_detail) [tr. {No autosave data will be stored until the model is saved somewhere else.}]
set msgs(no_autosave_full) [tr. {The following message was produced: %2$s. This may mean that the model was loaded from a read-only file system.}]

set msgs(lose_enum_type_title) [tr. {Model incompatibility}]
set msgs(lose_enum_type_message) [tr. {The components being merged include a definition for the enumerated type "%1$s", which will be replaced by the definition already in the model.}]
set msgs(lose_enum_type_full) [tr. {Old members: %2$s. Replaced by new members: %3$s.}]

set msgs(bad_sm_dim_title) [tr. {Problem with dimensions}]
set msgs(bad_sm_dim_message) [tr. {%1$s is not a valid dimension -- for a simple submodel, leave dimension field empty}]

set msgs(eqn_parse_fail_title) [tr. {Problem with equation parser}]
set msgs(eqn_parse_fail_message) [tr. {Simile was unable to make sense of the contents of the equation dialogue box.}]
set msgs(eqn_parse_fail_detail) [tr. {Please report this problem to your supplier.}]
set msgs(eqn_parse_fail_full) [tr. {While Simile attempts to produce a relevant message to anything that is entered in the equation field, sometimes it fails to do so.}]

set msgs(bad_syntax_title) [tr. {Syntax error}]
set msgs(bad_syntax_message) [tr. {The contents of the "%1$s" field could not be parsed.}]
set msgs(bad_syntax_detail) [tr. {The parser responded: %2$s}]

set msgs(wrong_bracket_count_title) [tr. {Wrong parameter name format}]
set msgs(wrong_bracket_count_message) [tr. {Your %1$s, %2$s, has brackets round it that identify it as %3$s.}]
set msgs(wrong_bracket_count_detail) [tr. {However it actually stands for %4$s so should appear as follows: %5$s.}]

set msgs(spare_interface_spec_title) [tr. {Cannot use interface data}]
set msgs(spare_interface_spec_message) [tr. {Could not find a free %1$s going %2$s the model with %3$s caption %4$s}]

set msgs(interface_mismatch_title) [tr. {Interface properties mismatch}]
set msgs(interface_mismatch_message) [tr. {%1$s a link of type %2$s from %3$s to %4$s, but it has properties %5$s whereas in the interface specification it is %6$s}]

set msgs(missing_relation_title) [tr. {Problem setting interface}]
set msgs(missing_relation_message) [tr. {Interface to submodel requires relation %1$s but this does not occur in the parent.}]

set msgs(unknown_unit_title) [tr. {Problem checking units}]
set msgs(unknown_unit_message) [tr. {Unit expression %1$s is not recognized as a valid unit.}]

set msgs(bad_type_conversion_title) [tr. {Problem converting units}]
set msgs(bad_type_conversion_message) [tr. {You are not allowed to convert implicitly from a "%1$s" value to a "%2$s" value because of the possibility for confusion or loss of information.}]

set msgs(replace_units_title) [tr. {Cannot keep previous units}]
set msgs(replace_units_message) [tr. {You cannot convert implicitly from a "%1$s" value to a "%2$s" value. Do you want to change the actual units for this component from "%2$s" to "%1$s"?}]
set msgs(replace_units_detail) [tr. {Note that this change may propagate to other components that are influenced by this one.}]

set msgs(is_scale_factor_title) [tr. {Esoteric use of unit matching}]
set msgs(is_scale_factor_message) [tr. {You have provided a unit specification, "%1$s", that is equivalent to a dimensionless non-unity scaling factor of %2$s. This will cause the associated value to be treated as a number of quantities of that size. You may continue if this is what you want.}]

set msgs(mismatched_dimensions_title) [tr. {Problem converting units}]
#set msgs(mismatched_dimensions_message) [tr. {The units of the required quantity are %1$s which have physical dimensions %2$s. These are incompatible with the supplied value, whose units %3$s have dimensions %4$s.}]
set msgs(mismatched_dimensions_message) [tr. {You are trying to convert a value with units %3$s to one with units %1$s. This cannot be done because the first has physical dimensions %4$s, while the second has physical dimensions %2$s.}]
set msgs(mismatched_dimensions_detail) [tr. {Please do one of the following:
* specify units with the same dimensions as the value, so it can be converted
* change the source of the value to have the units you wish, or
* clear the units specification entry to get the default units for this value.}]

set msgs(mismatched_arrays_title) [tr. {Problem converting units}]
set msgs(mismatched_arrays_message) [tr. {The units of the required quantity are %1$s which have array dimensions %2$s. These are incompatible with the array dimensions of the supplied value, which are %3$s.}]
set msgs(mismatched_arrays_detail) $msgs(mismatched_dimensions_detail)

set msgs(unwanted_syntax_title) [tr. {Parameter contains confusing characters}]
set msgs(unwanted_syntax_message) [tr. {Your %1$s, %2$s, contains characters that might cause the interpreter to confuse it with a compound expression.}]

set msgs(bad_table_data_title) [tr. {Problem with input data}]
set msgs(bad_table_data_message) [tr. {The data you specified is not suitable for a lookup table. %1$s}]

set msgs(bad_eqn_title) [tr. {Problem with equation}]
set msgs(bad_eqn_message) [tr. {%1$s}]

set msgs(field_needs_value_title) $msgs(bad_eqn_title)
set msgs(field_needs_value_message) [tr. {You must supply a value in the "%1$s" field.}]
set msgs(some_field_needs_value_title) $msgs(bad_eqn_title)
set msgs(some_field_needs_value_message) [tr. {You must supply a value in one of the "%1$s" fields.}]
set msgs(field_not_const_title) $msgs(bad_eqn_title)
set msgs(field_not_const_message) [tr. {Entry for %1$s must be a numeric constant.}]

set msgs(field_not_number_title) $msgs(bad_eqn_title)
set msgs(field_not_number_message) [tr. {Entry for %1$s must have a numerical value}]

set msgs(field_not_scalar_title) $msgs(bad_eqn_title)
set msgs(field_not_scalar_message) [tr. {Entry for %1$s must have a single value.}]

set msgs(bad_cond_spec_form_title) $msgs(bad_eqn_title)
set msgs(bad_cond_spec_form_message) [tr. {You have used the operator 'is' in a context which is not one of the forms used for looking up submodel instances.}]

set msgs(expr_denotes_list_title) $msgs(bad_eqn_title)
set msgs(expr_denotes_list_message) [tr. {The expression evaluates to a list, or array of lists. A model variable cannot represent a list.}]

set msgs(expr_denotes_per_record_array_title) $msgs(bad_eqn_title)
set msgs(expr_denotes_per_record_array_message) [tr. {The expression evaluates to an array whose size depends on the number of records in a file. A model variable cannot represent a variable-sized array.}]

set msgs(misplaced_cond_spec_title) $msgs(bad_eqn_title)
set msgs(misplaced_cond_spec_message) [tr. {You have used one of the forms for looking up submodel instances, but this component is not an existence condition.}]

set msgs(minmax_wrong_title) $msgs(bad_eqn_title)
set msgs(minmax_wrong_message) [tr. {Equation has non-numeric units %1$s, so minimum or maximum values cannot be used.}]

set msgs(bad_array_size_title) $msgs(bad_eqn_title)
set msgs(bad_array_size_message) [tr. {This equation conains the subexpression %1$s, which evaluates to a data structure which includes an array of size %2$s.}]
set msgs(bad_array_size_detail) [tr. {%2$s is not a valid dimension for a model component -- they must be integers greater than 1.}]

set msgs(bad_link_use_title) [tr. {Wrong use of inputs}]
set msgs(bad_link_use_message) [tr. {The equation uses the parameter "%1$s" from an incoming influence, but the component is marked as a file parameter, which cannot have influences from other components.}]
set msgs(unwanted_links_title) [tr. {Unwanted inputs}]
set msgs(unwanted_links_message) [tr. {This node has a link from %1$s, which is not used in the equation. Parameter default values are not allowed to have input variables themselves. Remove this link?}]

set msgs(undefined_parameter_title) [tr. {Undefined parameter}]
set msgs(undefined_parameter_message) [tr. {This expression contains the term %1$s, which appears to be used as a parameter, but it does not appear as a parameter name.}]
set msgs(undefined_parameter_detail) [tr. {The list of available parameters appears at the bottom of the equation dialogue or in the pull-down menu to the right of the equation bar.}]

set msgs(needs_array_or_list_title) [tr. {Wrong dimensionality of argument}]
set msgs(needs_array_or_list_message) [tr. {The function "%1$s" performs an operation over a list or array of values represented by its argument. The argument "%2$s" however represents only one value.}]

set msgs(avoid_var_size_inter_title) [tr. {Code generation problem}]
set msgs(avoid_var_size_inter_message) [tr. {This expression can only be converted into a running program by making an intermediate variable for the subexpression "%1$s".
 This subexpression has dimensions %2$s, where "var" represents a list, and "records" represents a resizable array.}]
set msgs(avoid_var_size_inter_detail) [tr. {Since this has a changing membership, it cannot be represented by a variable -- you need to do some more work inside the variable-membership submodel it comes from.}]

set msgs(misplaced_progenitor_ref_title) [tr. {Function has no value here}]
set msgs(misplaced_progenitor_ref_message) [tr. {The expression "%1$s" only has meaning inside a population submodel.}]

set msgs(needs_channel_parameter_title) [tr. {Argument must be channel}]
set msgs(needs_channel_parameter_message) [tr. {The argument of "channel_is" must be a value from a channel (creation, immigration, reproduction) for the population submodel containing its node. "%1$s" is not this sort of argument.}]

set msgs(bad_index_number_title) [tr. {Argument must be counting number}]
set msgs(bad_index_number_message) [tr. {The function "%2$s" sets or accesses some property of the model, and needs a non-negative scalar integer constant up to %3$s as an argument to allow the right code to be built into the model to do this. "%1$s" is not this sort of argument.}]

set msgs(needs_index_of_type_title) [tr. {Argument type wrong for array}]
set msgs(needs_index_of_type_message) [tr. {The function "%1$s", when applied to the array "%2$s", needs a value of type %3$s for its second argument. "%4$s" does not fit -- it has a value of type %5$s, which cannot be converted to a value of the required type.}]
set msgs(needs_index_of_type_detail) [tr. {The argument type must match the type used to create the array.}]

set msgs(redundant_array_title) [tr. {Equation is needlessly complicated}]
set msgs(redundant_array_message) [tr. {The equation contains the subexpression %1$s, which could be expressed more simply.}]

set msgs(index_number_out_of_range_title) [tr. {Index number out of range}]
set msgs(index_number_out_of_range_message) [tr. {You have used the index number %1$s, but it must be between 1 and the number of available indices, which is %2$s.}]

set msgs(only_works_on_array_title) [tr. {Argument must be array}]
set msgs(only_works_on_array_message) [tr. {The function "%1$s" needs a fixed membership array (of anything) for its first argument. "%2$s" does not fit -- it represents either a single value or a variable membership list.}]

set msgs(lost_user_defined_fn_title) [tr. {Function definition not found}]
set msgs(lost_user_defined_fn_message) [tr. {Attempting to process subexpression "%1$s": When this was entered, "%2$s" was a user-defined function (a procedure or macro) with %3$s arguments, but currently there is no definition for it.}]

set msgs(extra_links_title) [tr. {Too many inputs}]
set msgs(extra_links_message) [tr. {This node has a link from %1$s, which is not referred to by any of its parameter names in the equation. Remove this link?}]

set msgs(blind_add_title) [tr. {Failed to add component}]
set msgs(blind_add_message) [tr. {Simile will not add a %1$s where it will not currently be displayed!}]
set msgs(blind_add_detail) [tr. {Check 'Show detail' settings, and whether parent submodel contents are hidden.}]
set msgs(blind_add_full) [tr. {You tried to add a %1$s at depth %2$s.}]


set msgs(caption_clash_title) [tr. {Problem renaming component}]
set msgs(caption_clash_message) [tr. {Component %1$s cannot be renamed %2$s.}]
set msgs(caption_clash_detail) [tr. {The parent model of %1$s already contains a component called %2$s.}]
set msgs(caption_clash_full) [tr. {You are not allowed more than one component with the same caption in any one submodel.}]

set msgs(dodgy_chars_title) [tr. {Problem renaming component}]
set msgs(dodgy_chars_message) [tr. {Component %1$s cannot be renamed %2$s.}]
set msgs(dodgy_chars_detail) [tr. {The new name contains potentially confusing symbols "%3$s".}]
set msgs(dodgy_chars_full) [tr. {Slashes and dots are also used for showing hierarchies of folders or submodels.}]

set msgs(bad_ghost_title) [tr. {Ghosting error}]
set msgs(bad_ghost_message) [tr. {Unable to make ghost here}]

set msgs(show_full_button) [tr. {See full error text}]
set msgs(conversion_failure_title) [tr. {Problem building code}]
set msgs(conversion_failure_message) [tr. {Simile failed to convert %1$s (in submodel %2$s) into a program instruction.}]
set msgs(conversion_failure_detail) [tr. {This may be because Simile earlier failed to detect when a change elsewhere in the model made the equation for this component inconsistent, in which case editing this component again will make the model runnable.}]
# must be quoted so show_full msg gets subbed
set msgs(conversion_failure_full) [tr. "Parsing the equation for %1\$s (in %2\$s) gave this error code: %3\$s. Hit $msgs(show_full_button) to see the full message."]

set msgs(bad_parameter_title) [tr. {Problem interpreting equation}]
set msgs(bad_parameter_message) [tr. {The equation for component %1$s refers to an input parameter called "%2$s". This is not a valid parameter in the context of that component}]
set msgs(bad_parameter_detail) $msgs(conversion_failure_detail)

set msgs(bad_param_data_title) [tr. {Problem with parameter setup}]
set msgs(bad_param_data_message) [tr. {%1$s}]

# attempt at organization: following queries are raised from the Tcl code

set msgs(new_exec_needed_title) [tr. {Executable will be rebuilt}]
set msgs(new_exec_needed_message) [tr. {Simile attempted to reuse the existing executable or source code for this model, but failed. A new one will now be built.}]
set msgs(new_exec_needed_detail) [tr. {The operating system returned the following message: %1$s}]
set msgs(bad_license_code_title) [tr. {Wrong license code}]
set msgs(bad_license_code_message) [tr. {You have entered the wrong license code for your name, organization and Simile version. Please try again, ensuring you have the correct license code.}]
set msgs(dodgy_lib_title) [tr. {Dodgy filename}]
set msgs(dodgy_lib_message) [tr. {The compiler will only recognize shared library names that begin with "lib..."}]

set msgs(no_et_member_title) [tr. {No %1$s name}]
set msgs(no_et_member_message) [tr. {You must enter a name for the new %1$s in the box.}]
set msgs(bad_et_member_title) [tr. {Bad %1$s name}]
set msgs(bad_et_member_message) [tr. {"%2$s" is reserved for the value of a variable when it is not equal to any member of its type, or is not defined by the model.}]
set msgs(member_is_unit_title) [tr. {Unit name given for %1$s}]
set msgs(member_is_unit_message) [tr. {You cannot have a %1$s called %2$s because this name corresponds to a physical unit.}]
set msgs(member_is_unit_detail) [tr. {The unit's definition is %3$s}]
set msgs(duplicate_et_title) [tr. {Duplicate %1$s name}]
set msgs(duplicate_et_message) [tr. {This submodel already has an enumerated type called %2$s.}]
set msgs(duplicate_et_mem_title) [tr. {Duplicate %1$s name}]
set msgs(duplicate_et_mem_message) [tr. {The enumerated type %2$s in this submodel already contains a member called %3$s.}]

set msgs(read_image_failed_title) [tr. {Problem loading file}]
set msgs(read_image_failed_message) [tr. {Simile could not get an image from this file.}]
set msgs(read_image_failed_detail) [tr. {The reported problem was:
%1$s}]

set msgs(bad_access_title) [tr. {Problem opening file}]
set msgs(bad_access_message) [tr. {Simile could not open this file.}]
set msgs(bad_access_detail) [tr. {The reported problem was:
%1$s}]

set msgs(xml_parse_fail_title) [tr. {Failed to parse XML parameter metafile}]
set msgs(xml_parse_fail_message) [tr. {The XML parser gave the following message: %1$s}]
set msgs(xml_parse_fail_detail) [tr. {The parser status was:
%2$s}]
set msgs(bad_xml_spf_title) [tr. {Wrong kind of XML}]
set msgs(bad_xml_spf_message) [tr. {%1$s is not a Simile parameter metafile}]
set msgs(no_model_to_start_title) [tr. {No model running}]
set msgs(no_model_to_start_message) [tr. {You cannot invoke PEST because the model is not currently ready to run. Select "Model -> Run" and finish setting up the model for execution.}]
set msgs(measurements_missing_title) [tr. {No target values given}]
set msgs(measurements_missing_message) [tr. {You must supply at least one target value for each model output to be used by PEST}]
set msgs(pause_in_pest_exec_title) [tr. {PEST execution paused}]
set msgs(pause_in_pest_exec_message) [tr. {The PEST run has been paused at time %2$s. To continue it, you should first restart the model execution and allow the current model run to complete at time %1$s, then restart PEST execution.}]
set msgs(no_pest_output_title) [tr. {No PEST output}]
set msgs(no_pest_output_message) [tr. {PEST has not produced any output. Please check that it is installed and that the location of the executables is included in the PATH environment variable.}]
set msgs(failed_dir_reference_title)  [tr. {Missing parameter data directory}]
set msgs(failed_dir_reference_message) [tr. {The parameterization file contains a reference to data file "%1$s" for the parameter values for the component %2$s. This reference specifies the file path "%3$s" relative to the location of the parameterization file itself, so the file is being sought in the directory "%4$s", which does not exist on this computer.}]
set msgs(failed_dir_reference_detail) [tr. {Do you want to abort the operation, or skip the missing component values and continue loading the parameterization file, seeing all missing components together?}]
set msgs(failed_param_reference_title)  [tr. {Missing parameter data file}]
set msgs(failed_param_reference_message) [tr. {The parameterization file contains a reference to data file "%1$s" for the parameter values for the component %2$s. This reference specifies the file path "%3$s" relative to the location of the parameterization file itself, so the file is being sought in the directory "%4$s", where no file of this name exists.}]
set msgs(failed_param_reference_detail) $msgs(failed_dir_reference_detail)
set msgs(bad_v3x_param_title) [tr. {Bad parameter information}]
set msgs(bad_v3x_param_message) [tr. {Parameterization file contained the entry %1$s for component %2$s. The value at indices "%3$s" does not start with the name of an existing file, nor is it an allowed value for this component, which are %4$s.}]
set msgs(bad_v3x_param_detail) $msgs(failed_dir_reference_detail)
set msgs(unused_param_title) [tr. {Some parameter values unused}]
set msgs(unused_param_message) [tr. {The %1$s contains parameter values for the %2$s "%3$s", which does not exist in the target model "%4$s".}]
set msgs(unused_param_detail) [tr. {Do you want to ignore these values and continue loading the %1$s?}]
set msgs(unused_param_full) [tr. {You may also choose to select another %2$s which will get these values instead of "%3$s", for instance if it has been renamed since saving the parameters.}]

set msgs(param_load_fail_title) [tr. {Problem %1$sing %2$s value}]
set msgs(param_load_fail_message) [tr. {While attempting to %1$s the %2$s value "%3$s"%4$s, }]
# %4$s is " at indices x,y,z..." or empty
set msgs(param_load_fail_detail) [tr. {Do you want to stop this operation, or skip this field and continue %1$sing the %2$ss?}]

set msgs(bad_enum_type_mem_title) $msgs(param_load_fail_title)
set msgs(bad_enum_type_mem_message) $msgs(param_load_fail_message)[tr. {the entry "%5$s" appears where some %8$s value of type %6$s is expected. This must be one of %7$s.}]
set msgs(bad_enum_type_mem_detail) $msgs(param_load_fail_detail)

set msgs(zero_or_negative_index_title) $msgs(param_load_fail_title)
set msgs(zero_or_negative_index_message) $msgs(param_load_fail_message)[tr. {the index value %5$s appears which is zero or negative.}]
set msgs(zero_or_negative_index_detail) $msgs(param_load_fail_detail)

set msgs(non_integer_index_title) $msgs(param_load_fail_title)
set msgs(non_integer_index_message) $msgs(param_load_fail_message)[tr. {the entry "%5$s" appears where an index value of type integer is needed.}]
set msgs(non_integer_index_detail) $msgs(param_load_fail_detail)

set msgs(unwanted_param_array_title) $msgs(param_load_fail_title)
set msgs(unwanted_param_array_message) $msgs(param_load_fail_message)[tr. {the array "%5$s" appears where a single data point is needed.}]
set msgs(unwanted_param_array_detail) $msgs(param_load_fail_detail)

set msgs(data_not_number_title) $msgs(param_load_fail_title)
set msgs(data_not_number_message) $msgs(param_load_fail_message)[tr. {the data value "%5$s" appears instead of a numerical value.}]
set msgs(data_not_number_detail) $msgs(param_load_fail_detail)

set msgs(missing_param_data_title) $msgs(param_load_fail_title)
set msgs(missing_param_data_message) $msgs(param_load_fail_message)[tr. {there is an empty list where there should be a data point.}]
set msgs(missing_param_data_detail) $msgs(param_load_fail_detail)

set msgs(scalar_instead_of_array_title) $msgs(param_load_fail_title)
set msgs(scalar_instead_of_array_message) $msgs(param_load_fail_message)[tr. {a single data point "%5$s" appears where there should be an array of dimensions %6$s}]
set msgs(scalar_instead_of_array_detail) $msgs(param_load_fail_detail)

set msgs(odd_index_at_end_title) $msgs(param_load_fail_title)
set msgs(odd_index_at_end_message) $msgs(param_load_fail_message)[tr. {there are an odd number of entries instead of alternating index and value entries.}]
set msgs(odd_index_at_end_detail) $msgs(param_load_fail_detail)

set msgs(bad_time_point_index_title) $msgs(param_load_fail_title)
set msgs(bad_time_point_index_message) $msgs(param_load_fail_message)[tr. {a time point index appears which is not a numerical value or one of the special points %5$s}]
set msgs(bad_time_point_index_detail) $msgs(param_load_fail_detail)

set msgs(misplaced_fill_method_title) $msgs(param_load_fail_title)
set msgs(misplaced_fill_method_message) $msgs(param_load_fail_message)[tr. {the fill method "%5$s" appears, but is not preceded by the keyword "OTHERS".}]
set msgs(misplaced_fill_method_detail) $msgs(param_load_fail_detail)

set msgs(bad_uftsi_title) $msgs(param_load_fail_title)
set msgs(bad_uftsi_message) $msgs(param_load_fail_message)[tr. {the data point "%5$s" is given as the units for the time series indices. This should be a units expression with dimensions of time.}]
set msgs(bad_uftsi_detail) $msgs(param_load_fail_detail)

set msgs(misplaced_uftsi_title) $msgs(param_load_fail_title)
set msgs(misplaced_uftsi_message) $msgs(param_load_fail_message)[tr. {the expression "%5$s" appears to be for time series index units, but is not preceded by the keyword "INTERVAL".}]
set msgs(misplaced_uftsi_detail) $msgs(param_load_fail_detail)

set msgs(repeated_index_title) $msgs(param_load_fail_title)
set msgs(repeated_index_message) $msgs(param_load_fail_message)[tr. {index value "%5$s" appears more than once.}]
set msgs(repeated_index_detail) $msgs(param_load_fail_detail)

set msgs(record_count_undefined_title) $msgs(param_load_fail_title)
set msgs(record_count_undefined_message) $msgs(param_load_fail_message)[tr. {a per-record submodel containing only variable parameters must have time series values for at least one member.}]
set msgs(record_count_undefined_detail) $msgs(param_load_fail_detail)

set msgs(gap_in_data_title) $msgs(param_load_fail_title)
set msgs(gap_in_data_message) $msgs(param_load_fail_message)[tr. { the index and value are missing.}]
set msgs(gap_in_data_detail) $msgs(param_load_fail_detail)

set msgs(missing_array_title) $msgs(param_load_fail_title)
set msgs(missing_array_message) $msgs(param_load_fail_message)[tr. { there are no indices or values.}]
set msgs(missing_array_detail) $msgs(param_load_fail_detail)


set msgs(number_needed_title) [tr. {Numeric value required}]
set msgs(number_needed_message) [tr. {This operation could not be completed because a numeric value must be placed in the entry field that currently contains this text: %1$s}]
set msgs(wayward_grid_index_title) [tr. {Bad grid index location}]
set msgs(wayward_grid_index_message) [tr. {You have selected a row or column from which to read index values that is either within the data area or ouside the grid altogether.}]
set msgs(no_clear_val_title) [tr. {No value for clear}]
set msgs(no_clear_val_message) [tr. {The image file "%1$s" contains transparent pixels, but no value has been specified to use for these pixels.}]
set msgs(no_info_col_title) [tr. {%1$s column not found}]
set msgs(no_info_col_message) [tr. {The file "%2$s" does not contain a column with "%3$s" as a heading.}]
set msgs(no_info_col_detail) [tr. {Please supply a heading to identify the %1$s column from this list: %4$s.}]
set msgs(no_odbc_driver_title) [tr. {ODBC driver not found}]
set msgs(no_odbc_driver_message) [tr. {This system does not appear to have an ODBC driver available for files with the extension "%1$s".}]
set msgs(no_odbc_driver_detail) [tr. {You will probably need to install one and register it.}]
set msgs(area_misses_data_title) [tr. {Area contains no data}]
set msgs(area_misses_data_message) [tr. {The boundaries given do not enclose any usable data in this file.}]
set msgs(area_misses_data_detail) [tr. {Check that the file is of the right type and has enough rows and columns to cover the area specified.}]
set msgs(iotool_load_fail_title) [tr. {Error loading I/O tool code}]
set msgs(iotool_load_fail_message) [tr. {A problem occurred loading the code for an I/O tool, from file %1$s}]
set msgs(iotool_load_fail_detail) [tr. {The error message was:
%2$s}]
set msgs(iotool_load_fail_full) $msgs(iotool_load_fail_detail)
set msgs(iotool_restore_fail_title) [tr. {Problem restoring helper}]
set msgs(iotool_restore_fail_message) [tr. {A software error occurred while attempting to restore the I/O tool "%1$s" from the saved setup.}]
set msgs(iotool_restore_fail_detail) [tr. {Click "See all..." to see all error messages in full.}]
set msgs(iotool_restore_fail_full) [tr. {The error message was:
%2$s}]
set msgs(iotool_run_fail_title) [tr. {Error running I/O tool}]
set msgs(iotool_run_fail_message) [tr. {I/O tool "%1$s" raised a problem during model execution. This occurred while doing the %2$s operation.}]
set msgs(iotool_run_fail_detail) [tr. {The model has been paused. To continue running it you may have to kill this helper's display.}]
set msgs(iotool_run_fail_full) [tr. {The error message was:
%3$s
The helper's status was:
%4$s}]
set msgs(not_an_shf_title) [tr. {Unrecognized file format}]
set msgs(not_an_shf_message) [tr. {This file does not look like one of Simile's helper configuration files.}]
set msgs(wrong_layout_title) [tr. {Inappropriate view specification}]
set msgs(wrong_layout_message) [tr. {This view specification file was created within the integrated Model Run Environment. Do you wish to launch a view-only version of MRE to view it?}]
set msgs(missing_iotool_type_title) [tr. {Problem restoring helper}]
set msgs(missing_iotool_type_message) [tr. {No I/O tool with keyword "%1$s" is installed}]
set msgs(missing_var_requested_title) [tr. {Missing values for helper}]
set msgs(missing_var_requested_message) [tr. {An instance of the I/O tool "%1$s" has requested information about the %2$s %3$s, but there is no %2$s of this name in the current model.}]
set msgs(missing_var_requested_detail) [tr. {If the model has changed since the I/O tools were set up, you should adjust the settings of the I/O tools to reflect these changes, otherwise more warnings may appear and the model may stop running.}]
set msgs(no_spf_for_project_title) [tr. {Problem loading project}]
set msgs(no_spf_for_project_message) [tr. {Parameter metafile %1$s could not be found.}]

set msgs(unhandled_tcl_error_title) [tr. {Simile error}]
set msgs(unhandled_tcl_error_message) [tr. {Simile encountered an unexpected problem:
%1$s}]
set msgs(unhandled_tcl_error_full) {The error was:
%2$s}

set msgs(too_much_data_title) [tr. {Too much data}]
set msgs(too_much_data_message) [tr. {You have entered too much data into this dialogue. The limit is about 8000 characters.}]
set msgs(too_much_data_detail) [tr. {Hints: Use references to external documentation rather than very long comments. Put data values in parameter files rather than in equations. Express mathematical relationships in general rather than specific (if-then-elseif...) terms.}]

set msgs(type_error_title) [tr. {Simile error}]
set msgs(type_error_message) [tr. {An unhandled error occurred in the Prolog engine.}]
set msgs(type_error_detail) [tr. {Please contact your software supplier.}]
set msgs(type_error_full) [tr. {The error was:
%1$s}]

set msgs(cannot_delete_temp_folder_title) [tr. {Problem deleting temporary folder}]
set msgs(cannot_delete_temp_folder_message) [tr. {Simile could not delete its temporary folder %1$s. This probably means that it failed to unload a model executable.}]
set msgs(cannot_delete_temp_folder_detail) [tr. {Any saved models will not be affected, and you can delete the temporary folder after Simile has exited.}]

set msgs(home_not_set_title) [tr. {No HOME directory specified}]
set msgs(home_not_set_message) [tr. {Simile cannot determine which directory to use for its setup and temporary files.}]
set msgs(home_not_set_detail) [tr. {If you know which directory to use, set the HOME environment variable. For this session, Simile will attempt to use its installation folder instead.}]
set msgs(cannot_use_home_title) [tr. {File system problem}]
set msgs(cannot_use_home_message) [tr. {Simile could not create a folder within the HOME directory in which to save its setup and temporary files.}]
set msgs(cannot_use_home_detail) [tr. {For this session, Simile will attempt to use its installation folder instead.}]
set msgs(cannot_use_home_full) [tr. {The following error message was produced:
%1$s}]

set msgs(hack_break_title) [tr. {Code editing opportunity}]
set msgs(hack_break_message) [tr. {About to compile model.cpp in %1$s}]
set msgs(pkg_contents_title) [tr. {Saving project file}]
set msgs(pkg_contents_message) [tr. {This project file will contain the following information:
%1$s}]
set msgs(extn_bug_title) [tr. {Problem loading extension}]
set msgs(extn_bug_message) [tr. {There was an error loading a Simile extension from file %1$s}]
set msgs(extn_bug_full) [tr. {The error message was:
%2$s}]
set msgs(no_compiler_title) [tr. {Problem with c++ compiler setup}]
set msgs(no_compiler_message) [tr. {c++ compiler preference set to %1$s but no executable %2$s found.}]
set msgs(no_compiler_full) [tr. {The following directories were checked:
%1$s}]

set msgs(get_graphics_failed_title) [tr. {Problem copying graphics}]
set msgs(get_graphics_failed_message) [tr. {Simile failed to get graphics from the canvas to put on the clipboard, so it will not be possible to paste them into another application.}]
set msgs(get_graphics_failed_detail) [tr. {The copying process responded:
%1$s
The canvas must all be visible (i.e., on screen and not hidden) for this to work.}]

set msgs(save_eqn_bar_title) [tr. {Save text edits for %1$s}]
set msgs(save_eqn_bar_message) [tr. {The equation bar is currently editing the equation for %1$s. Do you want to save the changes you have made?}]

set msgs(finished_matches_title) [tr. {No more matches}]
set msgs(finished_matches_message) [tr. {No more matching %1$ss in this submodel context}]

# model diagnostics -- text mostly generated elsewhere
set msgs(model_crash_title) [tr. {Problem with model}]
set msgs(model_crash_message) [tr. {Simile ran into a problem trying to run this model.
While %1$s %2$s during %3$s of the model%4$s, %5$s.}]
set msgs(model_crash_full) [tr. {Original error message follows:
%6$s}]
set msgs(model_pause_title) [tr. {Model execution paused}]
set msgs(model_pause_message) [tr. {While %1$s %2$s during %3$s of the model%4$s, %5$s.}]

#These are from the run control and helpers
set msgs(model_out_of_date_title) [tr. {Model out of date}]
set msgs(model_out_of_date_message) [tr. {The model has been altered since the curent runnable version was built. Rebuild it now?}]

set msgs(not_runnable_title) [tr. {Cannot run model}]
set msgs(not_runnable_message) [tr. {The current model cannot run because it could not be built, or it failed to initialize, or it has been aborted during initialization.}]
set msgs(not_runnable_detail) [tr. {You could try selecting "Run" again, or "Debug" to get more information.}]

set msgs(params_not_loaded_title) [tr. {Fixed parameters not loaded}]
set msgs(params_not_loaded_message) [tr. {The model cannot run because it contains fixed input parameters for which no source is defined.}]
set msgs(model_has_exited_title) [tr. {Model has exited}]
set msgs(model_has_exited_message) [tr. {The model has run into a problem during execution and needs to be reset before it can run again.}]
set msgs(params_out_of_date_title) [tr. {Parameters out of date}]
set msgs(params_out_of_date_message) [tr. {Some file parameters have been changed since you last reset the model. Do you want to reset it now before running it?}]
set msgs(params_out_of_date_detail) [tr. {New file parameters will not take effect until you reset the model.}]
set msgs(manual_zero_title) [tr. {Not resetting model}]
set msgs(manual_zero_message) [tr. {You have manually edited the value for Current Time, setting it to zero. This action will not reset the model's state variables.}]
set msgs(manual_zero_detail) [tr. {Editing the current time causes to model to jump to the new time in a single execution step, which can lead to poor accuracy and zigzag traces on time plots. To reset the model and create new plot traces, click on the 'Reset simulation' button in the run control.}]
# Button text
set msgs(run_param_not_number_title) [tr. {Bad run parameter}]
set msgs(run_param_not_number_message) [tr. {Non-numeric value "%1$s" has been entered for run parameter %2$s -- replacing it with 1}]
set msgs(model_stuck_title) [tr. {Model step taking too long}]
set msgs(model_stuck_message) [tr. {This model appears to have got stuck with an endless or very long operation. Do you want to exit it now?}]
set msgs(not_number_title) [tr. {This must be a number}]
set msgs(not_number_message) [tr. {You need to enter a number in the %1$s field}]
set msgs(save_helper_setup_title) [tr. {Helper setup changed}]
set msgs(save_helper_setup_message) [tr. {The helper setup has been altered since it was last loaded or saved. Do you want to save it?}]

# debugging messages: just show the whole string
set msgs(debug_title) [tr. {Debugging info -- report to Simulistics}]
set msgs(debug_message) [tr. {The toolchain produced this message:
    %1$s}]

set msgs(ok_button) [tr. OK]
set msgs(yes_button) [tr. Yes]
set msgs(no_button) [tr. No]
set msgs(abort_button) [tr. {Give up}]
set msgs(forget_button) [tr. {Discard values}]
set msgs(reassign_button) [tr. {Use elsewhere}]
set msgs(abandon_button) [tr. {Don't save}]
set msgs(cancel_button) [tr. Cancel]
set msgs(save_button) [tr. Save]
set msgs(ignore_button) [tr. {Ignore log}]
set msgs(apply_button) [tr. {Apply log}]
set msgs(rename_button) [tr. {Rename}]
set msgs(keep_name_button) [tr. {Keep name}]
set msgs(update_shf_button) [tr. {Save current setup}]
set msgs(keep_shf_button) [tr. {Keep old setup}]
set msgs(lose_shf_button) [tr. {Save without helper setup}]

set geometryXYexplanation [tr. {Set position of the run control window, in the form xy, where x and y specify the desired location of window on the screen, in pixels.}]
set msgs(runControlPosition) $geometryXYexplanation
set msgs(slidersPosition) $geometryXYexplanation
set msgs(new) [tr. {New empty model}]
set msgs(open) [tr. {Open}]
set msgs(print) [tr. {Print}]
set msgs(save) [tr. {Save}]
set msgs(flip_v) [tr. {Flip the model diagram vertically}]
set msgs(flip_h) [tr. {Flip the model diagram horizontally}]
set msgs(tog_grid) [tr. {Hide or display grids in this window}]
set msgs(zoomin) [tr. {Zoom in}]
set msgs(zoomsel) [tr. {Zoom to selection}]
set msgs(zoomfit) [tr. {Zoom to fit}]
set msgs(zoomout) [tr. {Zoom out}]
set msgs(tableWimpOut) [tr. {The latest values have not been displayed because }]
set msgs(tooManyRows) [tr. {the total number of rows is greater than}]
set msgs(tooManyColumns) [tr. {the total number of columns is greater than}]
set msgs(tooManyCells) [tr. {the total number of cells is greater than}]

set msgs(wait_for_web) [tr. {Interacting with web service to convert file...}]
set msgs(too_many_pest_pts) [tr. {Warning -- too many measurements with indices %1$s}]

# references to documentation
set help(search) diagrams/search.htm
set help(g++) run/index.htm
set help(top) index.htm
set help(license) index.htm
set help(execution) run/index.htm
set help(circular) concepts/sd/influence.htm#circular
set help(fill_equation) equations/dialogue.htm
set help(user_defns) equations/macro.htm
set help(ext_code) submodels/external_code.htm
set help(expiry) coviewexpiry.htm
set help(helpers) run/tools/index.htm
set help(spf) data/scenario.htm
set help(data_in_cols) data/table/column.htm
set help(data_in_grid) data/table/grid.htm
set help(data_in_image) data/table/image.htm
set help(data_via_odbc) data/table/column.htm
set help(enumtype) equations/enumerated.htm
set help(model_dims) submodels/dialogue.htm
set help(pest_setup) run/pest/setup.htm

set url(coviewexpiry.htm) {Permanent licence upgrade}
set url(index.htm) {Contents}
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
set url(concepts/index.htm) {Model Diagram Elements}
set url(concepts/sd/compartment.htm) {Compartment}
set url(concepts/sd/flow.htm) {Flow arrow}
set url(concepts/sd/variable.htm) {Variable}
set url(concepts/sd/influence.htm) {Influence}
set url(concepts/object/submodel.htm) {Submodel}
set url(concepts/object/creation.htm) {Initialisation}
set url(concepts/object/immigration.htm) {Migration}
set url(concepts/object/reproduction.htm) {Reproduction}
set url(concepts/object/loss.htm) {Extermination}
set url(concepts/object/role.htm) {Role arrow}
set url(concepts/object/condition.htm) {Condition}
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

