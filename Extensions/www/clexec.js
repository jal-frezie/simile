// Utilities for loading and running Simile models as asm.js
//
// Jasper Taylor, Simulistics Ltd, 2016
//

// stuff for building and installing the model
similive_site = "http://hotwheels.lan/similive/model_action.php";

function json_to_saved_sml(mwStr,    // systo model in JSON form
			callback) { // function to call when done
    $.ajax({
	type: "POST",
	url: similive_site,
	data: {"act":"ConvertJSON", "js_mod":JSON.stringify(mwStr)}})
	.done(function(basePath) {
	    callback(basePath);
	}); // ConvertJson
}

function sml_to_asm_js(basePath, respond_to_param_req, show_model_time,
		       show_a_message, callback) {
    $.ajax({
	type: "POST",
	url: similive_site,
	data: {"act":"GetAsmJs", "base":basePath}})
	.done(function(returnedScript) {
	    $.ajax({
		type: "POST",
		url: similive_site,
		data: {"act" : "GetSVG",  "base" : basePath}
	    })
		.done (function(diagSVG) {
		    svgDoc = document.createElement("div");
		    svgDoc.innerHTML = diagSVG;
		    document.firstChild.appendChild(svgDoc);
		    // stick it where the sun don't shine
		}); // GetSVG
	    
	    window.eval(returnedScript);
	    aligner = _malloc(8); // aligned place

	    // load  the dll with the procedures it needs from the client
	    Module.ccall('proc_pointers_for_shank', 'number',
			 ['number','number','number'],
			 [Runtime.addFunction(respond_to_param_req),
			  Runtime.addFunction(show_model_time),
			  Runtime.addFunction(show_a_message)]);
	    
	    // Make space for model class ptr, and fill it
	    var pmodelType = _malloc(8); // a ptr
	    var complaint=Module.ccall('load_model', 'string',
				       ['string','string', 'number'],
				       ['./dummy.so','evaluation', pmodelType]);
	    modelType = getValue(pmodelType, '*');

	    if (complaint.length) {
		console.log("Problem creating type: " + complaint);
	    } else {
		console.log("Created model type OK");
	    }

	    // get data structure from model
	    populateStructs(modelType);
	    
	    callback(modelType);
	}); // GetAsmJs
}

// stuff for getting metadata from the model
var class_strs = ["SUBMODEL", "VARIABLE", "COMPARTMENT", "FLOW", "CONDITION",
		  "CREATION", "REPRODUCTION", "IMMIGRATION", "LOSS", "ALARM",
		  "EVENT", "SQUIRT", "STATE"];
var eval_strs = ["EXOGENOUS", "DERIVED", "TABLE", "INPUT", "GHOST", "LIMIT",
		 "RECALL", "BLOCK", "POPULATION", "GRID", "HONEYCOMB"];
var type_strs = ["VALUELESS", "REAL", "INTEGER", "FLAG",
		 "OWNSIZED", "SPARSEARRAY"];

function populateStructs(modelType) {
    var nodecount=Module.ccall('get_node_count', 'number', ['number'],
			       [modelType]);
    console.log("This model has " + nodecount + " components.");

    var name = _malloc(255); // string
    var ndims = _malloc(128); // 32 ints
    var types = _malloc(256); // 32 ptrs
    
    model_json = {};
    for (ncount=1; ncount<nodecount; ++ncount) {
	var nodedata = Module.ccall('get_data_line', 'number',
				    ['number','number'], [modelType, ncount]);
	var nd_name = Module.ccall('name_from_nodlin', 'string', ['number'],
				   [nodedata]);
	var nd_eqn = Module.ccall('eqn_from_nodlin', 'string', ['number'],
				  [nodedata]);
	// console.log("Checking component with id " + nd_name);

	Module.ccall('searchinfo', 'number',
		     ['string', 'number', 'number', 'number', 'number'],
		     [nd_name, modelType, name, ndims, types]);
	var cp = Pointer_stringify(name);
	// console.log("Checking component with caption path " + Pointer_stringify(name));

	// now get parent id...
	var lIO = cp.lastIndexOf('/');
	var pcp = cp.slice(0,lIO);
	var txt = cp.slice(lIO+1);
	if (pcp.length) {
	    parentId = Module.ccall('getNodeId', 'string', ['number','string'],
				    [modelType, pcp]);
	} else {
	    parentId = '#';
	}
	
	var dposn = 0;
	var dims = [];
	do {
	    dims[dposn] = getValue(ndims+4*dposn, 'i32');
	} while (dims[dposn++]);
	var nd_class = Module.ccall('class_from_nodlin', 'number', ['number'],
				    [nodedata]);
	var type = Module.ccall('type_from_nodlin', 'number', ['number'],
				[nodedata]);
	var min = Module.ccall('min_from_nodlin', 'number', ['number'],
			       [nodedata]);
	var max = Module.ccall('max_from_nodlin', 'number', ['number'],
			       [nodedata]);
	var evl = Module.ccall('eval_from_nodlin', 'number', ['number'],
			       [nodedata]);
	var us = Module.ccall('units_from_nodlin', 'string', ['number'],
			      [nodedata]);
	model_json[nd_name] = {"parent":parentId,"icon":"images/"
			       + class_strs[nd_class] + ".gif","text":txt,
			       "captpath":cp,"equation":nd_eqn,
			       "min":min, "max":max, "eval":eval_strs[evl],
			       "units":us, "type":type_strs[-type],"dims":dims};
    }
}

// stuff for getting values from a model instance

function MakeSubBlockSizes (dims) {
    var usedDims = 1;
    var dim0 = getValue(dims, 'i32');
    msbs_dims.push(dim0);
    var tName = type_strs[-dim0];
    if (dim0 < -5) { // enumerated type etc
	tName = "INTEGER";
    }
    if (tName != undefined) {
	sizes = [];
	switch (tName) {
	case "SPARSEARRAY":
	    msbs_dims.push(getValue(dims+4, 'i32')); // transcribe index count
	    usedDims = 2; // and fall through
	case "OWNSIZED":
	    sizes = MakeSubBlockSizes(dims+4*usedDims);
	    size = 8; // sizeof(sizeAndPtr);
	    break;
	case "REAL":
	    size = 8; // sizeof(double);
	    break;
	case "INTEGER":
	    size = 4; // sizeof(int);
	    break;
	case "FLAG":
	    size = 1; // sizeof(BOOLEAN);
	    break;
	case "VALUELESS":
	    size = 0;
	    break;
	}
    } else { // dimension
	sizes = MakeSubBlockSizes(dims+4);
	size = sizes[0] * dim0;
    }
    sizes.splice(0,0,size);
    return sizes;
}

var aligner; // aligned place
function brutally_align(ragged) {
    // will probably have to do something like below for all, since
    // booleans can cause odd alignment
    setValue(aligner, getValue(ragged, 'i32'), 'i32');
    setValue(aligner+4, getValue(ragged+4, 'i32'), 'i32');
}

function convert_to_js(dims, subBlocks, blob, count) {
    var localObj;
    var newBlob;
    if (dims[0] > 0) { // it's an array bound
	localObj = append_array_members(dims[0], dims.slice(1),
					subBlocks.slice(1), blob, count);
    } else {
	switch (type_strs[-dims[0]]) {
	case "OWNSIZED":
	    membership = Module.ccall('size_from_sznptr', 'number',
				      ['number'], [blob]);
	    newBlob = Module.ccall('ptr_from_sznptr', 'number',
				      ['number'], [blob]);
	    localObj = append_array_members(membership, dims.slice(1),
					    subBlocks.slice(1), newBlob, count);
	    break;
	case "SPARSEARRAY": 
	    // need clevers to nest indices; see old stuff
	    membership = Module.ccall('size_from_sznptr', 'number',
				      ['number'], [blob]);
	    newBlob = Module.ccall('ptr_from_sznptr', 'number',
				      ['number'], [blob]); // done
	    indices = [];
	    if (count[0]<0) { // start at last index group and work back
		newBlob = newBlob+(membership-1)*(dims[1]*4+subBlocks[1]);
	    }
	    pMemBlb = {'mem':membership, 'blb':newBlob};
// console.log("oblb", blob, JSON.stringify(pMemBlb), "vm dims", dims[1]);
	    localObj = append_list_members(dims[1], 0, dims.slice(2), indices,
					   subBlocks.slice(1), pMemBlb, count);
	    break;
	case "VALUELESS":
	    localObj = 'sm';
	    count[0] -= count[0]>0?1:-1;
	    break;
	case "REAL":
	    brutally_align(blob);
	    localObj = getValue(aligner, 'double');
	    count[0] -= count[0]>0?1:-1;
	    break;
	case "FLAG":
	    localObj = getValue(blob, 'i8');
	    count[0] -= count[0]>0?1:-1;
	    break;
	default: /* INTEGER or ENUM(*) */
	    localObj = getValue(blob, 'i32');
	    count[0] -= count[0]>0?1:-1;
	    break;
	}
    }
    return localObj;
}

function append_list_members(dimty, depth, dims, indices, 
			     subBlocks, pMemBlb, toGet) {
  var localObj;

  dir = toGet[0]>0?1:-1;
  if (depth==dimty) {
    if (pMemBlb.mem) {
      pMemBlb.blb += dimty*4;
      localObj = convert_to_js(dims, subBlocks, pMemBlb.blb, toGet);
      if (dir>0) {
	  pMemBlb.blb += subBlocks[0];
      } else {
	  pMemBlb.blb -= (subBlocks[0]+2*dimty*4);
      }
      --pMemBlb.mem;
    } else {
	localObj = {};
    }
  } else {
      localObj = {};
      while (pMemBlb.mem && toGet[0]) {
	  for (count=0; count<depth; ++count) {
	      if (getValue(pMemBlb.blb+4*count,'i32')!=indices[count])
		  return(localObj);
	  }
	  indices[depth] = getValue(pMemBlb.blb+4*depth,'i32');
	  var localSubObj = append_list_members(dimty, depth+1, dims, indices,
						subBlocks, pMemBlb, toGet);
	  if (localSubObj != {}) {
	      localObj[indices[depth].toString()] = localSubObj;
	  }
      }
  }
  return(localObj);
}

function append_array_members(membership, dims, subBlocks, blob, count) {
    var start, end, localObj = {};
    var dir = count[0]>0?1:-1;
    if (dir==1) {
	start = 1; end = membership+1;
    } else {
	start = membership; end = 0;
    }

    for (var offset = start; offset != end; offset += dir) {
	if (!count[0]) break;
	var localSubObj = convert_to_js(dims, subBlocks,
					blob+(offset-1)*subBlocks[0], count);
	if (localSubObj != {})
	    localObj[offset.toString()] = localSubObj;

    }
    return localObj;
}


function js_from_local_model(modelInstance, prolog, howMany) {
    c_result = Module.ccall('get_raw_values', 'number', ['string', 'number'],
			    [prolog, modelInstance]);
    if (c_result) {
//	console.log("Values retrieved OK");
    } else {
	console.log("Component has no data");
	return;
    }
    var ddims = Module.ccall('ds_from_nodvals', 'number', ['number'], [c_result]);
    var vals = Module.ccall('ct_from_nodvals', 'number', ['number'], [c_result]);

    msbs_dims = [];
    var sbList = MakeSubBlockSizes(ddims);
//    console.log("Sub-blocks:", JSON.stringify(sbList),
//		"Dims:", JSON.stringify(msbs_dims));
    var final = convert_to_js(msbs_dims, sbList, vals, [howMany]);
    Module.ccall('free_bloc_data', 'number', ['number', 'number'],
		 [vals, ddims]);
    _free(c_result);
    
    return final;
}
