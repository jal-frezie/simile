# Simile source code file: Run/messages.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file is sourced by toolbox.tcl, providing definitions of popup help text
# and links to help file pages.
#
set msgs(compartment) "Add compartments"
set msgs(flow) "Add flows"
set msgs(variable) "Add variables"
set msgs(influence) "Add influences"
set msgs(submodel) "Add new submodels"
set msgs(relation) "Connect submodels playing roles in a relationship to a relation submodel"
set msgs(condition) "Add conditions for the existence of submodel instances"
set msgs(alarm) "Add conditions for ending calculations within a submodel instance"
set msgs(text) "Add a text box to display additional information"
set msgs(creation) "Add creation processes to population submodels"
set msgs(immigration) "Add immigration processes to population submodels"
set msgs(reproduction) "Add reproduction processes to population submodels"
set msgs(loss) "Add destruction processes to population submodels"
set msgs(move) "Move diagram"
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

set msgs(sum) "Returns the sum of all elements of the argument"
set msgs(product) "Returns the product of all elements of the argument"
set msgs(place_in) "Returns each term's position, when making an array with makearay -- argument is nesting depth"
set msgs(count) "Returns the number of values in the argument"
set msgs(any) "Returns true if any of the argument elements are true"
set msgs(all) "Returns true if all of the argument elements are true"
set msgs(subtotals) "Returns an array with the cumulative totals of the values in the argument array. Element n of the result is the sum of argument elements 1 through n."
set msgs(rankings) "Returns an array with the ranks of the corresponding elements in the argument. This is 1 for the largest element, and equal to the size of the array for the smallest."
set msgs(colin) "Returns a random integer corresponding to an element of the argument array, with the probability of each value proportional to the value of that element"
set msgs(posgreatest) "returns the position of the highest value in the argument array, or the position of the first element with the highest value if there are more than one with that value"
set msgs(posleast) "returns the position of the lowest value in the argument array, or the position of the first element with the lowest value if there are more than one with that value"
set msgs(firsttrue) "Takes an array of booleans and returns the index of the first with value \"true\""
set msgs(howmanytrue) "Takes an array of booleans and returns the number that are true"
set msgs(parent) "Returns the index of the instance from which this one was reproduced, or 0 if this one was created or immigrated"
set msgs(init_time) "Returns the time at which this instance appeared -- argument is dummy"
set msgs(at_init) "Returns the value the argument had when first used, i.e., on model reset or when the submodel instance containing this equation was created"
set msgs(time) "Returns the current time, to nearest multiple of the time step specified by the argument -- none means that of current submodel"
set msgs(dt) "Returns the duration of the time step specified by the argument -- none means that of current submodel"
set msgs(prev) "Returns the value of this component the given number of time steps ago"
set msgs(makearray) "Returns an array of the given number of values from the first argument"
set msgs(element) "Returns a value from an array according to the second argument"
set msgs(first) "Returns \"true\" if argument is either the first member of its enumerated type or the integer 1"
set msgs(following) "Returns the enumerated type member that comes after its argument, or the argument plus one if it is an integer"
set msgs(preceding) "Returns the enumerated type member that comes before its argument, or the argument minus one if it is an integer"
set msgs(size) "Takes the name of a fixed-membership submodel and if one arg, returns its number of instances or if two, the size of one of its dimensions"
set msgs(stop) "If this gets executed, the model stops and displays a message including the argument. Use in a conditional statement to detect when things are going wrong."
set msgs(const_delay) "Returns the first argument delayed by the time given in the second argument, which must be a numeric value. Resolution is 0.1 day."
set msgs(var_delay) "Returns the first argument delayed by the time given in the second argument, which can be an expression. Resolution is 0.1 day and max delay is 100 days."
set msgs(least) "Returns the smallest value from an array/list of values"
set msgs(greatest) "Returns the largest value from an array/list of values"
set msgs(with_least) "Takes two arrays or lists with equal size, and returns the element of the second that corresponds to the element of the first with the smallest value."
set msgs(with_greatest) "Takes two arrays or lists with equal size, and returns the element of the second that corresponds to the element of the first with the largest value."
set msgs(abs) "Returns absolute difference between argument and zero"
set msgs(ceil) "Rounds argument up to a whole number"
set msgs(floor) "Rounds argument down to a whole number"
set msgs(channel_is) "Argument is an immigration, reproduction or creation channel. Returns true if this individual appeared through that channel."
set msgs(dies_of) "Argument is a mortality channel. Returns true if this channel will cause the individual to disappear at the end of the current time step."
set msgs(choose) "choose(a,b,c) is shorthand for 'if a then b else c'"
set msgs(exp) "Returns e to the power of a number"
set msgs(fmod) "Returns remainder after dividing first argument by second"
set msgs(hypot) "Returns length of hypotenuse of triangle with given base and height"
set msgs(atan2) {atan2(y x): Returns the angle to the baseline of the line from the origin to [x,y], ranging from -pi to pi}
set msgs(int) "Returns integer part of argument"
set msgs(last) "Returns value of argument from last time step"
set msgs(log) "Returns natural logarithm of argument"
set msgs(log10) "Returns base-10 logarithm of argument"
set msgs(max) "Returns greater of two values"
set msgs(min) "Returns lesser of two values"
set msgs(pow) "Returns first argument to the power of the second"
set msgs(round) "Returns the closest whole number to its argument"
set msgs(rand_var) "Returns a random number between the two arguments, with a new value every time step"
set msgs(rand_const) "Returns a random number between the two arguments, which stays the same until reset"
set msgs(sqrt) "Returns the square root of the argument. Calling this with a negative argument when running a model in Tcl under a version of Windows other than 95 original on an Intel Celeron processor can lead to mysterious crashes in Microsoft Office applications, especially early in the tax year."
set msgs(gaussian_var) "gaussian_var(mean sd): returns values from a gaussian distribution with \
        the given mean (mean) and standard deviation (sd)."
set msgs(poidev) "poidev(mean): returns values from a Poisson distribution with the given mean (mean)."
set msgs(binome) "binome(prob n): returns values from a binomial distribution resulting from n trials each of probability prob."
set msgs(hypergeom) "hypergeom(pop mark sample): Returns random samples from a hypergeometric distribution, i.e., the number of positives drawing 'sample' individuals from a population of 'pop' containing 'marked' positives."
set msgs(sgn) "sgn(r): returns the sign of r, -1 if negative or 1 if positive"
set msgs(initToolbar) "Display component bar in the desktop window when Simile starts, and in new submodel windows if they are large enough."
set msgs(initNavbar) "Display tool bar in the desktop window when Simile starts, and in new submodel windows if they are large enough."
set msgs(initEqnbar) "Display equation bar in the desktop window when Simile starts, and in new submodel windows if they are large enough."
set msgs(bigButtons) "Use alternative (larger) buttons for the tool bar and component bar."
set msgs(desktopDetail) "Sets the initial number of submodel levels to display. This can be changed later with the Window -> Display detail -> Submodels and Relations menu item."
set msgs(maxWinWidth) "Maximum width of a window, prevents new windows for complex submodels coming up huge. Maximum height is 3/4 of this."
set msgs(compChoice) "Default is gcc/g++ included in Simile distribution. Others must be installed on your system before you can use them."
set msgs(compDescPop) "Enable popups for component's equation when pointer hovers on component."
set msgs(compValPop) "Enable popups for component's current value(s) or instance indices when pointer hovers on component."
set msgs(compCmtPop) "Enable popups for component's description and comment text when pointer hovers on component."
set msgs(recentCount) "Save names of recently opened models for display on the File menu."
set msgs(saveExtras) "Save the canvas file to reduce the time initially taken to draw the model diagram."
set msgs(flowRouting) "Draw flows as a series of horizontal or vertical segments."
set msgs(deleteEndToEnd) "Delete all sections of multi-section influences or flows."
set msgs(helperManager) "Use single window to manange run time displays and controls."

set msgs(start_fail_title) "Simile has been unable to start up due to problems with this system."
set msgs(start_fail_message) "The following system error message was generated:\n%s"

set msgs(user_fn_misparse_title) "Parsing definitions in %s"
set msgs(user_fn_misparse_message) "Error parsing user-defined macros and functions in %s"
set msgs(user_fn_misparse_detail) "%2\$s"

set msgs(unused_macro_param_title) "Parsing definitions in %s"
set msgs(unused_macro_param_message) "Failed to parse macro definition:\n%s\nThe macro function contains the parameter %s, which does not appear in the arguments of the macro template"

set msgs(bad_user_fn_format_title) "Parsing definitions in %s"
set msgs(bad_user_fn_format_message) "The file %s contained the line %s which is in the wrong format for a macro, function or unit definition -- please refer to the documentation."

set msgs(bust_edition_limit_title) "Problem loading model"
set msgs(bust_edition_limit_message) "Loading this model makes ~d equations. This is greater than ~d, and it was not created by the enterprise edition, so it cannot be loaded in the ~a edition."
set msgs(bust_edition_limit_detail) "To upgrade, go to simulistics.com"

set msgs(save_edition_limit_title) "Problem saving model"
set msgs(save_edition_limit_message) "This model has %s equations. This is greater than %s, so it cannot be saved in the %s edition."
set msgs(save_edition_limit_detail) "To upgrade, go to simulistics.com"

set msgs(future_shock_title) "Future shock!"
set msgs(future_shock_message) "This file was created with a later version of Simile than the one you are currently running."
set msgs(future_shock_detail) "To avoid potential problems, please update your copy to version %s or later."

set msgs(lost_component_title) "Problem loading model"
set msgs(lost_component_message) "Component %s missing. The following lines in the file contained references to model components that were not found: %s"

set msgs(bad_model_format_title) "Problem loading model"
set msgs(bad_model_format_message) "Simile had some sort of problem incorporating the following lines from the file into the model: %s"
set msgs(bad_model_format_detail) "Although this data parses correctly, it does not make sense as part of a model specification in Simile's internal representation."

set msgs(linuxPrintFail_title) "Print command result"
set msgs(linuxPrintFail_message) "Printing seems to have failed."
set msgs(linuxPrintFail_detail) "The result returned by the print command was:\n\n%s"
set msgs(linuxPrintFail_full) "Please see the online help to find out more about setting up printing from Simile. Alternatively you can export the model diagram as a PostScript file (use the File...Export menu command) and then print that using another package."

set msgs(overlap_title) "Failed to %s %s"
set msgs(overlap_message) "Cannot %s %s here due to overlaps."
set msgs(overlap_full) "You can increase the amount of space available by reducing the \"Relative scale\" value in the Advanced section of the desktop or submodel properties."

set msgs(abandon_title) "Save changes"
set msgs(abandon_message) "The current version of %s (in %s) has not been saved. Leave anyway?"
set msgs(abandon_full) "If you don't save, the changes made in this session will be lost."

set msgs(open_model_failed_title) "Failed to open model"
set msgs(open_model_failed_message) "Simile could not open this file as a model."
set msgs(open_model_failed_detail) "It should be a model file or declaration list saved by Simile."
set msgs(open_model_failed_full) "This file could not be read as a MIME because: %s. It could not be read as a model description because: %s."

set msgs(flow_splits_at_border_title) "Problem with flow"
set msgs(flow_splits_at_border_message) "Flow %s cannot connect to compartment %s because its value would be split where it crosses the border of submodel %s"

set msgs(no_caption_match_title) "Submodel name mismatch"
set msgs(no_caption_match_message) "The interface specification you have chosen is for a submodel named %s, whereas the current submodel is named %s. Do you want the submodel renamed?"

set msgs(remove_orphan_title) "Correcting model inconsistency"
set msgs(remove_orphan_message) "Removing orphan node %s from submodel %s."

set msgs(compile_failed_title) "Problem during compilation"
set msgs(compile_failed_message) "The compiler raised a problem with the code generated for this model."
set msgs(compile_failed_detail) "It may help to try the 'Debug' option."
set msgs(compile_failed_full) "The error was: %s."

set msgs(link_inconsistency_title) "Problem with model"
set msgs(link_inconsistency_message) "This model cannot be built because ot contains an inconsistent link equivalence: %s."
set msgs(link_inconsistency_detail) "Please report this problem to your software supplier."

set msgs(unspecified_title) "Model is incomplete"
set msgs(unspecified_message) "Submodel \"%s\" contains incomplete component: \"%s\""
set msgs(unspecified_detail) "This component is shown in red, which means it has not been fully specified."
set msgs(unspecified_full) "Edit the equation of this component, or make it a file parameter."

set msgs(no_defining_param_title) "Required component missing"
set msgs(no_defining_param_message) "The membership of submodel \"%s\" is set by the number of values supplied for its fixed parameters, but it has no fixed parameters."

set msgs(no_seed_param_title) "Required component missing"
set msgs(no_seed_param_message) "The membership of submodel \"%s\" is set by the population channel symbols it contains. In order that the population have some members, it must contain at least one creation or immigration symbol, and it does not contain any."

set msgs(misplaced_channel_title) "Component in wrong place"
set msgs(misplaced_channel_message) "The component \"%s\" is a channel, which only has meaning if its parent is a population submodel, which submodel \"%s\" is not."

set msgs(missing_function_title) "User-defined function missing"
set msgs(missing_function_message) "This model cannot be built because it contains the user-defined function %s"
set msgs(missing_function_detail) "%s should have a definition in the file %s, but this file is missing."

set msgs(no_such_function_title) "Non-existent function used"
set msgs(no_such_function_message) "Attempting to process subexpression \"%s\": Simile does not include \"%s\" as a function."

set msgs(wrong_no_of_args_title) "Wrong number of args"
set msgs(wrong_no_of_args_message) "Attempting to process subexpression \"%s\": You have tried to use the macro or function \"%s\" with %s arguments, but it must take %s"

set msgs(missing_graph_or_table_data_title) "Built-in data missing"
set msgs(missing_graph_or_table_data_message) "Subexpression \"%s\" is a reference to a data table or sketch graph, but no data has been entered for it."
set msgs(missing_graph_or_table_data_detail) "Use the Graph and Table buttons in the equation dialogue to add these functions and define data for them."

set msgs(cannot_combine_argument_dimensions_title) "Argument dimensions incompatible"
set msgs(cannot_combine_argument_dimensions_message) "Simile cannot work out what dimensions the result of \"%s\" should have -- the dimensions of the arguments are incompatible."

set msgs(mismatched_units_title) "Argument types incompatible"
set msgs(mismatched_units_message) "The arguments of the function \"%s\" in the term \"%s\" have the following types: %s. These cannot be matched to the expected argument types for this function, which are %s."

set msgs(unused_inter_title) "Unused intermediate result"
set msgs(unused_inter_message) "The equation is badly formed because it creates the explicit intermediate result %s, which is not subsequently used."

set msgs(parameter_name_reused_title) "Problem with intermediate result name"
set msgs(parameter_name_reused_message) "The equation is badly formed because it creates the explicit intermediate result %s, which is also the name of an input parameter."

set msgs(parameter_name_recurs_title) "Problem with intermediate result name"
set msgs(parameter_name_recurs_message) "The equation is badly formed because it creates the explicit intermediate result %s in the scope of an earlier explicit intermediate result with the same name."

set msgs(circular_evaluation_title) "Problem with model design"
set msgs(circular_evaluation_message) "This model cannot be executed because it contains the following circular set(s) of function evaluations: %s"

set msgs(condition_outside_loop_title) "Problem with model design"
set msgs(condition_outside_loop_message) "This model contains the target %1\$s which depends on its own values from previous iterations of a program loop. However the cycle of evaluations includes target %2\$s, which is calculated outside the innermost program loop containing target %1\$s"

set msgs(undecipherable_operand_title) "Problem getting number"
set msgs(undecipherable_operand_message) "%s does not stand for a number in the context of %s"

set msgs(submodel_name_recurs_title) "Problem getting number"
set msgs(submodel_name_recurs_message) "Cannot resolve reference to size of %s. There are multiple submodels of this name."

set msgs(absent_submodel_title) "Problem getting number"
set msgs(absent_submodel_message) "Cannot resolve reference to size of %s. There is no submodel of this name."

set msgs(submodel_size_variable_title) "Problem getting number"
set msgs(submodel_size_variable_message) "%s has a reference to a variable membership model in its dimensions."

set msgs(absent_enum_type_title) "Problem getting number"
set msgs(absent_enum_type_message) "Cannot resolve reference to size of %s in component %s. There is no local enumerated type of this name."

set msgs(enum_type_mix_title) "Inconsistent type definitions"
set msgs(enum_type_mix_message) "You cannot refer to the value of %s at this point because it depends on the enumerated type %s, which at that point has the definition %s but here has the definition %s"

set msgs(param_in_vm_model_title) "Problem with model"
set msgs(param_in_vm_model_message) "There is an external parameter, %s, inside a variable-membership submodel, %s."
set msgs(param_in_vm_model_detail) "This is not allowed, as the number of values in the file cannt change as the membership of the submodel does."
set msgs(param_in_vm_model_full) "Perhaps a per-record submodel, with its membership set by the number of records in the file, is needed here."

set msgs(offer_restore_title) "Restore option"
set msgs(offer_restore_message) "Simile left a log file of unsaved changes when this model was last edited."
set msgs(offer_restore_detail) "Ignore changes, or apply?"
set msgs(offer_restore_full) "You can ignore these changes and edit the model as it was saved, or apply them to get back to where you were when Simile exited."

set msgs(no_autosave_title) "Autosave warning!"
set msgs(no_autosave_message) "Could not create an autosave file called %s for this model."
set msgs(no_autosave_detail) "No autosave data will be stored until the model is saved somewhere else."
set msgs(no_autosave_full) "The following message was produced: %2\$s. This may mean that the model was loaded from a read-only file system."

set msgs(lose_enum_type_title) "Model incompatibility"
set msgs(lose_enum_type_message) "The components being merged include a definition for the enumerated type \"%s\", which will be replaced by the definition already in the model."
set msgs(lose_enum_type_full) "Old members: %2\$s. Replaced by new members: %3\$s."

set msgs(bad_sm_dim_title) "Problem with dimensions"
set msgs(bad_sm_dim_message) "%s is not a valid dimension -- for a simple submodel, leave dimension field empty"

set msgs(eqn_parse_fail_title) "Problem with equation parser"
set msgs(eqn_parse_fail_message) "Simile was unable to make sense of the contents of the equation dialogue box."
set msgs(eqn_parse_fail_detail) "Please report this problem to your supplier."
set msgs(eqn_parse_fail_full) "While Simile attempts to produce a relevant message to anything that is entered in the equation field, sometimes it fails to do so."

set msgs(bad_syntax_title) "Syntax error"
set msgs(bad_syntax_message) "The contents of the \"%s\" field could not be parsed."
set msgs(bad_syntax_detail) "The parser responded: %2\$s"

set msgs(wrong_bracket_count_title) "Wrong parameter name format"
set msgs(wrong_bracket_count_message) "Your %s, %s, has brackets round it that identify it as %s."
set msgs(wrong_bracket_count_detail) "However it actually stands for %4\$s so should appear as follows: %5\$s."

set msgs(spare_interface_spec_title) "Cannot use interface data"
set msgs(spare_interface_spec_message) "Could not find a free %s going %s the model with %s caption %s"

set msgs(interface_mismatch_title) "Interface properties mismatch"
set msgs(interface_mismatch_message) "%s a link of type %s from %s to %s, but it has properties %s whereas in the interface specification it is %s"

set msgs(missing_relation_title) "Problem setting interface"
set msgs(missing_relation_message) "Interface to submodel requires relation %s but this does not occur in the parent."

set msgs(unknown_unit_title) "Problem checking units"
set msgs(unknown_unit_message) "Unit expression %s is not recognized as a valid unit."

set msgs(bad_type_conversion_title) "Problem converting units" 
set msgs(bad_type_conversion_message) "You are not allowed to convert implicitly from a \"%s\" value to a \"%s\" value because of the possibility for confusion or loss of information." 

set msgs(mismatched_dimensions_title) "Problem converting units"
set msgs(mismatched_dimensions_message) "The units of the required quantity are %s which have physical dimensions %s. These are incompatible with the supplied value, whose units %s have dimensions %s."
set msgs(mismatched_dimensions_detail) "Please do one of the following:\n* specify units with the same dimensions as the value\n* change the source of the value to have the units you wish, or\n* clear the units specification entry to get the default units for this value."

set msgs(mismatched_arrays_title) "Problem converting units"
set msgs(mismatched_arrays_message) "The units of the required quantity are %s which have array dimensions %s. These are incompatible with the dimensions of the supplied value, which are %s."
set msgs(mismatched_arrays_detail) $msgs(mismatched_dimensions_detail)

set msgs(unwanted_syntax_title) "Parameter contains confusing characters"
set msgs(unwanted_syntax_message) "Your %s, %s, contains characters that might cause the interpreter to confuse it with a compound expression."

set msgs(bad_table_data_title) "Problem with input data"
set msgs(bad_table_data_message) "The data you specified is not suitable for a lookup table. %s"

set msgs(bad_eqn_title) "Problem with equation"
set msgs(bad_eqn_message) "%s"

set msgs(field_needs_value_title) $msgs(bad_eqn_title)
set msgs(field_needs_value_message) "You must supply a value in the \"%s\" field."
set msgs(field_not_const_title) $msgs(bad_eqn_title)
set msgs(field_not_const_message) "Entry for %s must be a numeric constant."

set msgs(field_not_number_title) $msgs(bad_eqn_title)
set msgs(field_not_number_message) "Entry for %s must have a numerical value"

set msgs(field_not_scalar_title) $msgs(bad_eqn_title)
set msgs(field_not_scalar_message) "Entry for %s must have a single value."

set msgs(expr_denotes_list_title) $msgs(bad_eqn_title)
set msgs(expr_denotes_list_message) "The expression evaluates to a list, or array of lists. A model variable cannot represent a list."

set msgs(minmax_wrong_title) $msgs(bad_eqn_title)
set msgs(minmax_wrong_message) "Equation has non-numeric units %s, so minimum or maximum values cannot be used."

set msgs(bad_array_size_title) $msgs(bad_eqn_title)
set msgs(bad_array_size_message) "This equation evaluates to a data structure which includes an array of size %s."
set msgs(bad_array_size_detail) "%s is not a valid dimension for a model component -- they must be integers greater than 1."

set msgs(unwanted_links_title) "Unwanted inputs"
set msgs(unwanted_links_message) "This node has a link from %s, but parameter default values are not allowed to have input variables themselves. Remove this link?"

set msgs(undefined_parameter_title) "Undefined parameter"
set msgs(undefined_parameter_message) "This expression contains the term %s, which appears to be used as a parameter, but it does not appear as a parameter name."
set msgs(undefined_parameter_detail) "The list of available parameters appears at the bottom of the equation dialogue or in the pull-down menu to the right of the equation bar."

set msgs(needs_array_or_list_title) "Wrong dimensionality of argument"
set msgs(needs_array_or_list_message) "The function \"%s\" performs an operation over a list or array of values represented by its argument. The argument \"%s\" however represents only one value."

set msgs(avoid_var_size_inter_title) "Code generation problem"
set msgs(avoid_var_size_inter_message) "This expression can only be conberted into a running program by making an intermediate variable for the subexpression \"%s\".\n This subexpression has dimensions %s, where \"var\" represents a list."
set msgs(avoid_var_size_inter_detail) "Since this has a changing membership, it cannot be represented by a variable -- you need to do some more work inside the variable-membership submodel it comes from."

set msgs(needs_channel_parameter_title) "Argument must be channel"
set msgs(needs_channel_parameter_message) "The argument of \"channel_is\" must be a value from a channel (creation, immigration, reproduction) for the population submodel containing its node. \"%s\" is not this sort of argument."

set msgs(bad_index_number_title) "Argument must be counting number"
set msgs(bad_index_number_message) "The function \"%2\$s\" sets or accesses some property of the model, and needs a non-negative scalar integer constant as an argument to allow the right code to be built into the model to do this. \"%1\$s\" is not this sort of argument."

set msgs(needs_index_of_type_title) "Argument type wrong for array"
set msgs(needs_index_of_type_message) "The function \"%s\", when applied to the array \"%s\", needs a value of type %s for its second argument. \"%s\" does not fit -- it has a value of type %s, which cannot be converted to a value of the required type."
set msgs(needs_index_of_type_detail) "The argument type must match the type used to create the array."

set msgs(index_number_out_of_range_message) "You have used the index number %s, but it must be between 1 and the number of available indices, which is %s."

set msgs(only_works_on_array_title) "Argument must be array"
set msgs(only_works_on_array_message) "The function \"%s\" needs a fixed membership array (of anything) for its first argument. \"%s\" does not fit -- it represents either a single value or a variable membership list."

set msgs(lost_user_defined_fn_title) "Function definition not found"
set msgs(lost_user_defined_fn_message) "Attempting to process subexpression \"%s\": When this was entered, \"%s\" was a user-defined function (a procedure or macro) with %s arguments, but currently there is no definition for it."

set msgs(extra_links_title) "Too many inputs"
set msgs(extra_links_message) "This node has a link from %s, which is not referred to by any of its parameter names in the equation. Remove this link?"

set msgs(blind_add_title) "Failed to add component"
set msgs(blind_add_message) "Simile will not add a %s where it will not currently be displayed!"
set msgs(blind_add_detail) "Check 'Show detail' settings, and whether parent submodel contents are hidden."
set msgs(blind_add_full) "You tried to add a %s at depth %s."


set msgs(caption_clash_title) "Problem renaming component"
set msgs(caption_clash_message) "Component %s cannot be renamed %s."
set msgs(caption_clash_detail) "The parent model of %s already contains a component called %s."
set msgs(caption_clash_full) "You are not allowed more than one component with the same caption in any one submodel."

set msgs(dodgy_chars_title) "Problem renaming component"
set msgs(dodgy_chars_message) "Component %s cannot be renamed %s."
set msgs(dodgy_chars_detail) "The new name contains potentially confusing symbols \"%3\$s\"."
set msgs(dodgy_chars_full) "Slashes and dots are also used for showing hierarchies of folders or submodels."

set msgs(bad_ghost_title) "Ghosting error"
set msgs(bad_ghost_message) "Unable to make ghost here"

set msgs(show_full_button) "See full error text"
set msgs(conversion_failure_title) "Problem building code"
set msgs(conversion_failure_message) "Simile failed to convert %s (in submodel \%s) into a program instruction."
set msgs(conversion_failure_detail) "This may be because Simile earlier failed to detect when a change elsewhere in the model made the equation for this variable inconsistent, in which case editing this variable again will make the model runnable."
set msgs(conversion_failure_full) "Parsing the equation for %s (in %s) gave this error code: %s. Hit \"$msgs(show_full_button)\" to see the full message."

set msgs(bad_param_data_title) "Problem with parameter setup"
set msgs(bad_param_data_message) "%s"

# attempt at organization: following queries are raised from the Tcl code

set msgs(new_exec_needed_title) "Executable will be rebuilt"
set msgs(new_exec_needed_message) "Simile attempted to reuse the existing executable or source code for this model, but failed. A new one will now be built."
set msgs(new_exec_needed_detail) "The operating system returned the following message: %s"
set msgs(bad_license_code_title) "Wrong license code"
set msgs(bad_license_code_message) "You have entered the wrong license code for your name, organization and Simile version. Please try again, ensuring you have the correct license code."
set msgs(dodgy_lib_title) "Dodgy filename"
set msgs(dodgy_lib_message) "The compiler will only recognize shared library names that begin with \"lib...\""

set msgs(no_et_member_title) "No %s name"
set msgs(no_et_member_message) "You must enter a name for the new %s in the box."
set msgs(bad_et_member_title) "Bad %s name"
set msgs(bad_et_member_message) "NULL is reserved for the value of a variable when it is not equal to any member of its type."
set msgs(member_is_unit_title) "Unit name given for %s"
set msgs(member_is_unit_message) "You cannot have a %s called %s because this name corresponds to a physical unit."
set msgs(member_is_unit_detail) "The unit's definition is %3\$s"
set msgs(duplicate_et_title) "Duplicate %s name"
set msgs(duplicate_et_message) "This submodel already has an enumerated type called %2\$s."
set msgs(duplicate_et_mem_title) "Duplicate %s name"
set msgs(duplicate_et_mem_message) "The enumerated type %2\$s in this submodel already contains a member called %3\$s."

set msgs(read_image_failed_title) "Problem loading file"
set msgs(read_image_failed_message) "Simile could not get an image from this file."
set msgs(read_image_failed_detail) "The reported problem was:\n%s"

set msgs(xml_parse_fail_title) "Failed to parse XML parameter metafile"
set msgs(xml_parse_fail_message) "The XML parser gave the following message: %s"
set msgs(xml_parse_fail_detail) "The parser status was:\n%2\$s"
set msgs(bad_xml_spf_title) "Wrong kind of XML"
set msgs(bad_xml_spf_message) "%s is not a Simile parameter metafile"
set msgs(measurements_missing_title) "No target values given"
set msgs(measurements_missing_message) "You must supply at least one target value for each model output to be used by PEST"
set msgs(failed_dir_reference_title)  "Missing parameter data directory"
set msgs(failed_dir_reference_message) "The parameterization file contains a reference to data file \"%s\" for the parameter values for the component %s. This reference specifies the file path \"%s\" relative to the location of the parameterization file itself, so the file is being sought in the directory \"%s\", which does not exist on this computer."
set msgs(failed_dir_reference_detail) "Do you want to abort the operation, or skip the missing component values and continue loading the parameterization file, seeing all missing components together?"
set msgs(failed_param_reference_title)  "Missing parameter data file"
set msgs(failed_param_reference_message) "The parameterization file contains a reference to data file \"%s\" for the parameter values for the component %s. This reference specifies the file path \"%s\" relative to the location of the parameterization file itself, so the file is being sought in the directory \"%s\", where no file of this name exists."
set msgs(failed_param_reference_detail) $msgs(failed_dir_reference_detail)
set msgs(bad_v3x_param_title) "Bad parameter information"
set msgs(bad_v3x_param_message) "Parameterization file contained the entry %s for component %s. This entry does not start with the name of an existing file, nor is it an allowed value for this component, which are %s."
set msgs(bad_v3x_param_detail) $msgs(failed_dir_reference_detail)
set msgs(unused_param_title) "Some parameter values unused"
set msgs(unused_param_message) "The %s contains parameter values for the %s %s, which does not exist in the target model %s."
set msgs(unused_param_detail) "Do you want to stop this operation, or ignore these values and continue loading the %s?"
set msgs(param_load_fail_title) "Problem setting %s value"
set msgs(param_load_fail_message) "While attempting to load the %s value \"%s\"%s the following problem occurred: %s"
set msgs(param_load_fail_detail) "Do you want to stop this operation, or skip this field and continue loading the %ss?"

set msgs(number_needed_title) "Numeric value required"
set msgs(number_needed_message) "This operation could not be completed because a numeric value must be placed in the entry field that currently contains this text: %s"
set msgs(no_clear_val_title) "No value for clear"
set msgs(no_clear_val_message) "The image file \"%s\" contains transparent pixels, but no value has been specified to use for these pixels."
set msgs(no_data_col_title) "Data column not found"
set msgs(no_data_col_message) "The file \"%s\" does not contain a column with \"%s\" as a heading."
set msgs(no_data_col_detail) "Please supply a heading to identify the data column from this list: %3\$s."
set msgs(no_odbc_driver_title) "ODBC driver not found"
set msgs(no_odbc_driver_message) "This system does not appear to have an ODBC driver available for files with the extension \"%s\"."
set msgs(no_odbc_driver_detail) "You will probably need to install one and register it."
set msgs(iotool_load_fail_title) "Error loading I/O tool code"
set msgs(iotool_load_fail_message) "A problem occurred loading the code for an I/O tool, from file %s"
set msgs(iotool_load_fail_detail) "The error message was:\n%2\$s"
set msgs(iotool_load_fail_full) $msgs(iotool_load_fail_detail)
set msgs(iotool_restore_fail_title) "Problem restoring helper"
set msgs(iotool_restore_fail_message) "A software error occurred while attempting to restore the I/O tool \"%s\" from the saved setup."
set msgs(iotool_restore_fail_detail) "Click \"See all...\" to see all error messages in full."
set msgs(iotool_restore_fail_full) "The error message was:\n%2\$s"
set msgs(iotool_run_fail_title) "Error running I/O tool"
set msgs(iotool_run_fail_message) "I/O tool \"%s\" raised a problem during model execution. This occurred while doing the %s operation."
set msgs(iotool_run_fail_detail) "The model has been paused. To continue running it you may have to kill this helper's display."
set msgs(iotool_run_fail_full) "The error message was:\n%3\$s"
set msgs(not_an_shf_title) "Unrecognized file format"
set msgs(not_an_shf_message) "This file does not look like one of Simile's helper configuration files."
set msgs(wrong_layout_title) "Inappropriate view specification"
set msgs(wrong_layout_message) "This view specification file was created within the integrated Model Run Environment. Do you wish to launch a view-only version of MRE to view it?" 
set msgs(missing_iotool_type_title) "Problem restoring helper"
set msgs(missing_iotool_type_message) "No I/O tool with keyword \"%s\" is installed"
set msgs(missing_var_requested_title) "Missing values for helper"
set msgs(missing_var_requested_message) "An instance of the I/O tool \"%s\" has requested information about the %s %s, but there is no %s of this name in the current model."
set msgs(missing_var_requested_detail) "If the model has changed since the I/O tools were set up, you should adjust the settings of the I/O tools to reflect these changes, otherwise more warnings may appear and the model may stop running."
set msgs(no_spf_for_project_title) "Problem loading project"
set msgs(no_spf_for_project_message) "Parameter metafile %s could not be found."

set msgs(unhandled_tcl_error_title) "Simile error"
set msgs(unhandled_tcl_error_message) "Simile encountered an unexpected problem:\n%s"
set msgs(unhandled_tcl_error_full) %2\$s

set msgs(type_error_title) "Simile error"
set msgs(type_error_message) "An unhandled error occurred in the Prolog engine."
set msgs(type_error_detail) "Please contact your software supplier."
set msgs(type_error_full) "The error was:\n%s"

set msgs(cannot_delete_temp_folder_title) "Problem deleting temporary folder"
set msgs(cannot_delete_temp_folder_message) "Simile could not delete its temporary folder %s. This probably means that it failed to unload a model executable."
set msgs(cannot_delete_temp_folder_detail) "Any saved models will not be affected, and you can delete the temporary folder after Simile has exited."

set msgs(home_not_set_title) "No HOME directory specified"
set msgs(home_not_set_message) "Simile cannot determine which directory to use for its setup and temporary files."
set msgs(home_not_set_detail) "If you know which directory to use, set the HOME environment variable. For this session, Simile will attempt to use its installation folder instead."
set msgs(cannot_use_home_title) "File system problem"
set msgs(cannot_use_home_message) "Simile could not create a folder within the HOME directory in which to save its setup and temporary files."
set msgs(cannot_use_home_detail) "For this session, Simile will attempt to use its installation folder instead."
set msgs(cannot_use_home_full) "The following error message was produced:\n%s"

set msgs(hack_break_title) "Code editing opportunity"
set msgs(hack_break_message) "About to compile model.cpp in %s"
set msgs(pkg_contents_title) "Saving project file"
set msgs(pkg_contents_message) "This project file will contain the following information:\n%s"
set msgs(extn_bug_title) "Problem loading extension"
set msgs(extn_bug_message) "There was an error loading a Simile extension from file %s"
set msgs(extn_bug_full) "The error message was:\n%2\$s"
set msgs(no_compiler_title) "Problem with c++ compiler setup"
set msgs(no_compiler_message) "c++ compiler preference set to %s but no executable %s found."
set msgs(no_compiler_full) "The following directories were checked:\n%s"

set msgs(get_graphics_failed_title) "Problem copying graphics"
set msgs(get_graphics_failed_message) "Simile failed to get graphics from the canvas to put on the clipboard, so it will not be possible to paste them into another application."
set msgs(get_graphics_failed_detail) "The canvas must all be visible (i.e., on screen and not hidden) for this to work."

set msgs(save_eqn_bar_title) "Save text edits for %s"
set msgs(save_eqn_bar_message) "The equation bar is currently editing the equation for %s. Do you want to save the changes you have made?"

set msgs(finished_matches_title) "No more matches"
set msgs(finished_matches_message) "No more matching %ss in this submodel context"

# model diagnostics -- text mostly generated elsewhere
set msgs(model_crash_title) "Problem with model"
set msgs(model_crash_message) "Simile ran into a problem trying to run this model.\nWhile %s %s during %s of the model%s, %s."
set msgs(model_crash_full) "Original error message follows:\n%6\$s"
set msgs(model_pause_title) "Model execution paused"
set msgs(model_pause_message) "While %s %s during %s of the model%s, %s."

#These are from the run control and helpers
set msgs(model_out_of_date_title) "Model out of date"
set msgs(model_out_of_date_message) "The model has been altered since the curent runnable version was built. Rebuild it now?"

set msgs(not_runnable_title) "Cannot run model"
set msgs(not_runnable_message) "The current model cannot run because it could not be built, or it failed to initialize, or it has been aborted."
set msgs(not_runnable_detail) "You could try selecting \"Run\" again, or \"Debug\" to get more information."

set msgs(params_not_loaded_title) "Fixed parameters not loaded"
set msgs(params_not_loaded_message) "The model cannot run because it contains fixed input parameters for which no source is defined."
set msgs(model_has_exited_title) "Model has exited"
set msgs(model_has_exited_message) "The model has run into a problem during execution and needs to be reset before it can run again."
set msgs(params_out_of_date_title) "Parameters out of date"
set msgs(params_out_of_date_message) "Some file parameters have been changed since you last reset the model. Do you want to reset it now before running it?"
set msgs(params_out_of_date_detail) "New file parameters will not take effect until you reset the model."
set msgs(manual_zero_title) "Not resetting model"
set msgs(manual_zero_message) "You have manually edited the value for Current Time, setting it to zero. This action will not reset the model's state variables."
set msgs(manual_zero_detail) "Editing the current time causes to model to jump to the new time in a single execution step, which can lead to poor accuracy and zigzag traces on time plots. To reset the model and create new plot traces, click on the 'Reset simulation' button in the run control."
# Button text
set msgs(run_param_not_number_title) "Bad run parameter"
set msgs(run_param_not_number_message) "Non-numeric value \"%s\" has been entered for run parameter %s -- replacing it with 1"
set msgs(model_stuck_title) "Model step taking too long"
set msgs(model_stuck_message) "This model appears to have got stuck with an endless or very long operation. Do you want to exit it now?"
set msgs(not_number_title) "This must be a number"
set msgs(not_number_message) "You need to enter a number in the %s field"
set msgs(save_helper_setup_title) "Helper setup changed"
set msgs(save_helper_setup_message) "The helper setup has been altered since it was last loaded or saved. Do you want to save it?"


set msgs(ok_button) OK
set msgs(yes_button) Yes
set msgs(no_button) No
set msgs(abort_button) "Give up"
set msgs(forget_button) "Don't save"
set msgs(cancel_button) Cancel
set msgs(save_button) Save
set msgs(ignore_button) "Ignore log"
set msgs(apply_button) "Apply log"
set msgs(rename_button) "Rename"
set msgs(keep_name_button) "Keep name"
set msgs(update_shf_button) "Save current setup"
set msgs(keep_shf_button) "Keep old setup"
set msgs(lose_shf_button) "Save without helper setup"

set geometryXYexplanation "Set position of the run control window, in the form xy, where x and y specify the desired location of window on the screen, in pixels."
set msgs(runControlPosition) $geometryXYexplanation
set msgs(slidersPosition) $geometryXYexplanation
set msgs(new) "New empty model"
set msgs(open) "Open"
set msgs(print) "Print"
set msgs(save) "Save"
set msgs(flip_v) "Flip the model diagram vertically"
set msgs(flip_h) "Flip the model diagram horizontally"
set msgs(tog_grid) "Hide or display grids in this window"
set msgs(zoomin) "Zoom in"
set msgs(zoomsel) "Zoom to selection"
set msgs(zoomfit) "Zoom to fit"
set msgs(zoomout) "Zoom out"
set msgs(tableWimpOut) "The latest values have not been displayed because "
set msgs(tooManyRows) "the total number of rows is greater than"
set msgs(tooManyColumns) "the total number of columns is greater than"
set msgs(tooManyCells) "the total number of cells is greater than"

# references to documentation
set help(g\\+\\+) "run/index.htm"
set help(top) "index.htm"
set help(license) "index.htm"
set help(execution) "run/index.htm"
set help(fill_equation) "equations/dialogue.htm"
set help(user_defns) "equations/macro.htm"
set help(ext_code) "submodels/external_code.htm"
set help(expiry) "coviewexpiry.htm"
set help(helpers) "run/tools/index.htm"
set help(spf) "data/scenario.htm"
set help(data_in_cols) "data/case5.htm"
set help(data_via_odbc) "data/case5.htm"
set help(enumtype) "equations/enumerated.htm"
set help(model_dims) "submodels/dialogue.htm"
set help(pest_setup) "run/pest/setup.htm"

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

