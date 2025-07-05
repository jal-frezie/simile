function Layers2D (port) {
  this.port = port;
    this.tgts = [];
    this.State = [];
    this.scaleGrp = d3.select('#' + port)
	    .style("image-rendering","pixelated")
            .style("image-rendering","-moz-crisp-edges")
            .style("image-rendering","-o-crisp-edges").append("svg")
	.attr("width",800).attr("height",480).attr("id", port + "_diag")
	.append("g");
    this.diagZoom = d3.behavior.zoom()
	.on("zoom", function () {
	    d3.select('#' + port + '_diag').select('g')
		.attr("transform", "translate(" + d3.event.translate +
		      ")scale(" + d3.event.scale + ")");
	});
    d3.select('#' + port + '_diag').attr("class","pane").call(this.diagZoom);
  this.status = "displaying";
}

Layers2D.prototype.addLayer = function (type, state) {
    layerSpec = {};
    var startComps = this.tgts.length;
    layerSpec.type = type;
    if (type == "Photo20131023")
	layerSpec.setup = state;
    else if (type == "Circles20171122" || type == "Lines20171122") {
	// state is 1 element list
	layerSpec.setup = [];
	for (var i=0; i<state[0].length;i++) {
	    entry = state[0][i];
	    possCapt = tclListOfDimty(entry,1);
	    if (possCapt[0] == ",colours") {
		possCapt = tclListOfDimty(entry,2); // everything nested deeper
		entry = idFromCapt(possCapt[1].join(" "));
		this.tgts.push(entry);
		layerSpec.legend = [];
		for (var j=2; j<possCapt.length;j++) {
		    layerSpec.legend.push(ShortenColour(possCapt[j][0]));
		}
	    } else if (possCapt[0][0] == "/") { // its a capt path
		entry = idFromCapt(possCapt.join(" "));
		this.tgts.push(entry);
	    } else if (possCapt[0][0] == "#") { // it's a fixed colour
		entry = ShortenColour(possCapt[0]);
	    }
	    layerSpec.setup.push(entry);
	}
	trans = tclListOfDimty(state[1],1);
	if (trans[0] == "layer_transform") {
	    layerSpec.trans = "translate("
	    +trans[1]+","+-trans[2]+")scale("
		+trans[3]+","+-trans[4]+")";
	} else
	    console.log("Unknown shape layer property " + trans[0]);
    } else 
	for (var i=0; i<state.length-1;i+=2) {
	    if (type == "Polygon20131026") // indices start /WIN/,
		state[i] = state[i].substr(6);
	    possCapt = tclListOfDimty(state[i+1],1);
	    if (possCapt[0][0] == "/") { // its a capt path
		state[i+1] = idFromCapt(possCapt.join(" "));
		if (type != "InputPointer20210609") // not getting, setting!
		    this.tgts.push(state[i+1]);
	    }
	    layerSpec[state[i]] = state[i+1];
	}
    layerSpec.gLayer = this.scaleGrp.append("g");
    var endComps = this.tgts.length;
    
    var layerIndex = this.State.length;
    this.State.push(layerSpec);
    var that = this;

    // now do any one-off processing a new layer requires
    switch (type) {
    case "RectGrid20131119":
	this.hex = (model_json[model_json[layerSpec.color].parent].eval ==
		    "HONEYCOMB");
	spread=1;
	if (this.hex) {
	    spread *= 2;
	}
	gifWid=spread*layerSpec.ncol;
	grpAttr = "translate("
	    +layerSpec.xoff+","+-layerSpec.yoff+")scale("
	    +layerSpec.xscale/spread+","+-layerSpec.yscale+")";
	layerSpec.image = layerSpec.gLayer.append("svg:image")
	    .attr("width",gifWid)
	    .attr("height",layerSpec.nrow)
	    .attr("pointer-events", "none")
	    .attr("transform",grpAttr)
	    .attr("xlink:href", "images/bigsimile.gif");
	// find tgts entry for colour and sub it with gif data request
	colourIdx = this.tgts.indexOf(layerSpec.color);
	layerSpec.gifReq = {"format":"binary","node":this.tgts[colourIdx],
			    "bottom":layerSpec.min,"top":layerSpec.max,
			    "nswat":layerSpec.nswatches,"hex":this.hex};
	this.tgts[colourIdx] = layerSpec.gifReq;
	// then make legend for display
	swatArr = [];
	for (var i=0; i<=layerSpec.nswatches; ++i)
	    swatArr.push(layerSpec["c" + i]);
	layerSpec.cMap = ColorMapFromSwatches(swatArr);
	layerSpec.gifHeader = makeGifHeader(gifWid, layerSpec.nrow,
					    layerSpec.cMap);
	break;
    case "Polygon20131026": // and maybe others
	swatArr = [];
	for (var i=0; i<=layerSpec.nswatches; ++i)
	    swatArr.push(layerSpec["c" + i]);
	layerSpec.cMap = ColorMapFromSwatches(swatArr);
	break;
    case "Photo20131023": // no updates so display it here
	localURL = "data:image/png;base64," + layerSpec.setup[5].join("");
	photo = layerSpec.gLayer.selectAll("image").data([0]);
        var image = photo.enter()
            .append("svg:image")
	    .attr("pointer-events", "none")
            .attr("xlink:href", localURL)
            .attr("preserveAspectRatio","none");
	// cannot get pixel size of svg image so have to make a separate html
	// one for this purpose...
	var img = document.createElement("img");
	var trans = layerSpec.setup.slice(0,4);
	img.src = localURL;
	img.onload=function () {
	    natWide = img.naturalWidth;
	    natHigh = img.naturalHeight;
	    image.attr("x",trans[0]).attr("y", -trans[1]-natHigh*trans[3])
		.attr("width", natWide*trans[2])
		.attr("height", natHigh*trans[3]);
	}
	break;
    case "Animals20131029":
	grpAttr = "translate("
	    +layerSpec.transform.slice(0,2).join(",")+")scale("
	    +layerSpec.transform.slice(2,4).join(",")+")";
	layerSpec.gLayer.attr("transform",grpAttr);
	var tclCmdList = [];
	useful = layerSpec.cmds.slice(1, layerSpec.cmds.indexOf("set"));
	while ((brk = useful.indexOf("$c")) > -1) {
	    tclCmdList.push(useful.slice(0,brk).join(" ").split("  ").join(" {} ")); // add {} for empty lists
	    useful = useful.slice(brk+1);
	}
	tclCmdList.push(useful.join(" ").split("  ").join(" {} ")); // final cmd
	useful = layerSpec.cmds.slice(layerSpec.cmds.indexOf("set"));
	for (var i=0; i<useful.length-2; i+=3) {
	    layerSpec[useful[i+1]] = useful[i+2];
	}
	break;
    case "InputPointer20210609":
	layerSpec.domElt = d3.select('#' + this.port + '_diag').node();
	layerSpec.actCount = 0;
	layerSpec.domElt.addEventListener("mousedown",startStroke);
	layerSpec.domElt.addEventListener("mousemove",continueStroke);
	layerSpec.domElt.addEventListener("mouseup",finishStroke);
	layerSpec.domElt.addEventListener("touchstart",startStroke);
	layerSpec.domElt.addEventListener("touchmove",continueStroke);
	layerSpec.domElt.addEventListener("touchend",finishStroke);
	break;
    case "Circles20171122":
    case "Lines20171122":
	layerSpec.gLayer.attr("transform",layerSpec.trans);
    }
    // are the two local copies for posts tripping each other up??
    $.post('model_action.php', {"base":fileBase, "act":"Query",
				"note":JSON.stringify(this.tgts.slice(startComps, endComps))},
	   function(resp) {
	       responses = JSON.parse(resp);
	       var sorted = {};
	       for (var i=startComps; i<endComps; ++i) {
		   if (that.tgts[i].constructor === Object) {
		       resIndx = JSON.stringify(that.tgts[i]);
		   } else {
		       resIndx = that.tgts[i];
		   }
		   
		   sorted[resIndx] = responses[i-startComps];
	       }
	       if (type == "Animals20131029") // need to translate glyph 1st
		   $.post('model_action.php',
			  {"base":fileBase,"act":"Can2SVG",
			   "cnvdraw":JSON.stringify(tclCmdList)},
			  function(resp) {
			      that.State[layerIndex].draw = resp;
			      that.displayLayer(0.0, sorted, 0, layerIndex);
			  });
	       else
		   that.displayLayer(0.0, sorted, 0, layerIndex);
	   });
}

function doStroke(evt, action) {
    if (evt.button != undefined && evt.button != 0) return;
    var tgt = evt.target;
    // OK, how do I get the context back?
    var inUse = currentHelpers[tgt.parentNode.id];
    // console.log("retrieved " + myTab);
    if (inUse == undefined) return;
    if (action == 1) {
	var noZoom = d3.behavior.zoom().on("zoom",null);
	d3.select('#' + inUse.port + '_diag').call(noZoom);
    } else if (action == -1) {
	d3.select('#' + inUse.port + '_diag').call(inUse.diagZoom);
    }
    var found = false;
 	for (var n in inUse.State) {
 	    layerSpec = inUse.State[n];
	//console.log("Trying " + layerSpec.type);
	    // hope is OK if none!
	    if (layerSpec.domElt == evt.target) {
	    // console.log("Success!");
	    found = true;
	    break;
	    }
	}
	if (!found || action == 0 && layerSpec.actCount == 0) return; // non-drag move
    if (action == -1)
        layerSpec.actCount = action;
    layerSpec.actCount += 1;
    
    // Now map the coords back to model space
    const pt = tgt.createSVGPoint();
    if (evt.type == "touchstart" || evt.type == "touchmove" || evt.type == "touchend") {
	evt = evt.changedTouches[0];
    }
    pt.x = evt.clientX;
    pt.y = evt.clientY;
    const modelP = pt.matrixTransform(tgt.lastElementChild.getScreenCTM().inverse());
    console.log("Translated " + pt.x + ", " + pt.y + " to " + modelP.x + ", " + modelP.y);
    parmBlock = {};
    parmBlock[model_json[layerSpec.xcoord].captpath] = 'NOW ' + (1+modelP.x);
    parmBlock[model_json[layerSpec.ycoord].captpath] = 'NOW ' + (1-modelP.y);
    parmBlock[model_json[layerSpec.tgt].captpath] = 'NOW ' + layerSpec.actCount;
    sendValues(parmBlock);
    // model_reset(1);
} // ok debug that!

function startStroke(evt) {
	doStroke(evt,1);
}
  
function continueStroke(evt) {
	doStroke(evt,0);
}

function finishStroke(evt) {
	doStroke(evt,-1);
}
  
Layers2D.prototype.display = function (time, latest, connect) {
    for (var layer in this.State)
	this.displayLayer(time, latest, connect, layer)
}
    
Layers2D.prototype.displayLayer = function (time, latest, connect, layerIndex) {
    layerSpec = this.State[layerIndex];
    switch (layerSpec.type) {
	
    case "RectGrid20131119":
	arr = latest[JSON.stringify(layerSpec.gifReq)];
	layerSpec.image.attr("xlink:href", layerSpec.gifHeader + arr);
	break;
	
    case "Polygon20131026":
	colScaler = 255/(layerSpec.max-layerSpec.min);
	colours = flatten('m', latest[layerSpec.color]);
	if (!connect) { // redraw poly borders
	    layerSpec.gLayer.selectAll("polygon").remove(); // delete old polys
	    for (var inds in colours) {
		indArr = inds.split(",");
		niceInds = indArr.join("_");
		pts = "";
		if (layerSpec.xcoord == "HEX_CTRS") {
		    hex_centre_y = 1.5*indArr[0];
		    hex_centre_x = 1.732*(indArr[1]*1+(indArr[0]%2)/2.0)
		    for (var i=0; i<=6; i++) {
			xpt = hex_centre_x+1.732*[0,1,1,0,-1,-1,0][i]/2;
			ypt = hex_centre_y+[1,0.5,-0.5,-1,-0.5,0.5,1][i];
			pts = pts + xpt + "," + -ypt + " ";
		    }
		} else {
		    // get poly vertices from model
		}
		colFract = Math.floor((colours[inds]-layerSpec.min)*colScaler);
		colSpec = colorFrom(layerSpec.cMap, colFract);
		layerSpec.gLayer.append("polygon")
		    .attr("id", 'poly' + niceInds).attr("points",pts)
		    .attr("fill",colSpec).attr("stroke","black")
		    .attr("pointer-events", "none")
		    .attr("stroke-width",0);
	    }
	} else {
	    // recolour existing pollies
	    for (var inds in colours) {
		indArr = inds.split(",");
		niceInds = indArr.join("_");
		colFract = Math.floor((colours[inds]-layerSpec.min)*colScaler);
		colSpec = colorFrom(layerSpec.cMap, colFract);
		layerSpec.gLayer.select('#poly' + niceInds).attr("fill",colSpec);
	    }
	}
	break;
	
    case "Animals20131029":
	layerSpec.gLayer.selectAll("g").remove(); // delete old critters
	allDefns = {}
	for (i=0;i<4;++i) {
	    allDefns[["xs","ys","sizes","dirs"][i]] =
		addAsApprop(latest,
			    layerSpec[["xcoord","ycoord","size","dir"][i]]);
	}
	defns = flattenAll("a", allDefns, 0);

	for (var bg in defns) {
	    defn = defns[bg];
	    var sc=defn.sizes;
	    var y=-defn.ys-(layerSpec.hotspot[1]*sc/layerSpec.scale);
	    var x=defn.xs-(layerSpec.hotspot[0]*sc/layerSpec.scale);
	    var r=[(ToRadians(layerSpec.axis)-ToRadians(defn.dirs))*180/3.14,
		   layerSpec.hotspot[0],layerSpec.hotspot[1]];
	    trans = "translate("+x+","+y+")scale("+(sc/layerSpec.scale)+")rotate("+r+")";
	    layerSpec.gLayer.append("g").html(layerSpec.draw)
		.attr("transform",trans);
	}
	break;
    case "Circles20171122":
	layerSpec.gLayer.selectAll("circle").remove();
	allDefns = {};
	for (i=0;i<4;++i)
	    allDefns[["x_axis","y_axis","radius","color"][i]] =
	    addAsApprop(latest, layerSpec.setup[[1,2,4,5][i]]);
	defns = flattenAll("c", allDefns, 0);

	for (var bg in defns) {
	    if (layerSpec.legend == undefined) {
		hexColor = defns[bg].color;
	    } else {
		hexColor = layerSpec.legend[Math.floor(defns[bg].color)];
	    }
	    layerSpec.gLayer.append("circle").attr("cx",defns[bg].x_axis)
		.attr("cy",defns[bg].y_axis)
		.attr("r",defns[bg].radius)
		.attr("pointer-events", "none")
		.attr("fill", hexColor);
	}
	break;
    case "Lines20171122":
	layerSpec.gLayer.selectAll("line").remove();
	allDefns = {};
	for (i=0;i<6;++i)
	    allDefns[["startx","starty","endx","endy","width","color"][i]] =
	    addAsApprop(latest, layerSpec.setup[[1,2,4,5,7,8][i]]);
	defns = flattenAll("l", allDefns, 0);

	for (var bg in defns) {
	    if (layerSpec.legend == undefined) {
		hexColor = defns[bg].color;
	    } else {
		hexColor = layerSpec.legend[Math.floor(defns[bg].color)];
	    }
	    layerSpec.gLayer.append("line").attr("x1",defns[bg].startx)
		.attr("y1",defns[bg].starty)
		.attr("x2",defns[bg].endx)
		.attr("y2",defns[bg].endy)
		.attr("pointer-events", "none")
		.attr("style", "stroke:" + hexColor + ";stroke-width:" + defns[bg].width);
	}
    }
}
    
Layers2D.prototype.resize = function (x,y) {
//   if (this.status != "displaying") return;
//   console.log('Tab width: ' + d3.select('#' + this.port).style('width'));
//   console.log('Notebook height: ' + d3.select('#tabs').style('height'));
    ngap = 40;
//      w = 800;
      w = x-ngap;
//      h = 800;
      h = y-ngap;
    d3.select('#' + this.port + '_diag').attr("width",w).attr("height",h);

    // problem: getbbox returns 0s if diagram not visible
    // -- so need to either raise any notebook tabs I am
    // in, or do this inline -- works fine if done here!
    if (this.scaleGrp.attr("transform") == null) {
	bbox = this.scaleGrp[0][0].getBBox();
	//console.log("x " + bbox.x + " y " + bbox.y + " w " + bbox.width +
	//	   " h " + bbox.height + " spc " + w + "," + h);
	if (bbox.width==0) return;
	initScale = Math.min(w/bbox.width,h/bbox.height);
	this.diagZoom.translate([-initScale*bbox.x,-initScale*bbox.y])
	    .scale(initScale);
	grpAttr = "translate("+-initScale*bbox.x+","+-initScale*bbox.y+
	    ")scale("+initScale+","+initScale+")";
	this.scaleGrp.attr("transform",grpAttr);
    }
}

function ToRadians (axis) {
    if ((ct = ["e", "ne", "n", "nw", "w", "sw", "s", "se"].indexOf(axis)) > -1)
	return ct*6.28/8;
    if ((ct = ["3h", "2h", "1h", "12h", "11h", "10h", "9h", "8h", "7h", "6h", "5h", "4h"].indexOf(axis)) > -1)
	return ct*6.28/12;
    fl = parseFloat(axis);
    if (!isNaN(fl))
	return fl;
    else
	console.log("Unrecognized axis " + axis);
}
