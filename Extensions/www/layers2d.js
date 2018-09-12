function Layers2D (port) {
  this.port = port;
    this.tgts = [];
    this.State = [];
    this.scaleGrp = d3.select('#' + port)
	    .style("image-rendering","pixelated").append("svg")
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
	    if (possCapt[0][0] == "/") { // its a capt path
		entry = idFromCapt(possCapt.join(" "));
		this.tgts.push(entry);
	    } else if (possCapt[0][0] == "#") { // it's a fixed colour
		var colBytes = BytesFromHex(possCapt[0]);
		entry = 65536*colBytes.R+256*colBytes.G+colBytes.B;
	    }
	    layerSpec.setup.push(entry);
	}
    } else 
	for (var i=0; i<state.length-1;i+=2) {
	    if (type == "Polygon20131026") // indices start /WIN/,
		state[i] = state[i].substr(6);
	    possCapt = tclListOfDimty(state[i+1],1);
	    if (possCapt[0][0] == "/") { // its a capt path
		state[i+1] = idFromCapt(possCapt.join(" "));
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
	grpAttr = "translate(0,0)scale("
	    +layerSpec.xscale+","+-layerSpec.yscale+")";
	layerSpec.gLayer.attr("transform",grpAttr);
	layerSpec.image = layerSpec.gLayer.append("svg:image")
	    .attr("width",layerSpec.ncol + "px")
	    .attr("height",layerSpec.nrow + "px")
	    .attr("xlink:href", "images/bigsimile.gif");
	// find tgts entry for colour and sub it with gif data request
	colourIdx = this.tgts.indexOf(layerSpec.color);
	layerSpec.gifReq = {"format":"binary","node":this.tgts[colourIdx],
			    "bottom":layerSpec.min,"top":layerSpec.max,
			    "nswat":layerSpec.nswatches};
	this.tgts[colourIdx] = layerSpec.gifReq;
	// then make legend for display
	swatArr = [];
	for (var i=0; i<=layerSpec.nswatches; ++i)
	    swatArr.push(layerSpec["c" + i]);
	layerSpec.cMap = ColorMapFromSwatches(swatArr);
	layerSpec.gifHeader = makeGifHeader(layerSpec.ncol, layerSpec.nrow,
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
	    var hexColor = defns[bg].color.toString(16);
	    layerSpec.gLayer.append("circle").attr("cx",defns[bg].x_axis)
		.attr("cy",-defns[bg].y_axis)
		.attr("r",defns[bg].radius)
		.attr("fill", "#" + "000000".slice(hexColor.length) + hexColor);
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
	    var hexColor = defns[bg].color.toString(16);
	    layerSpec.gLayer.append("line").attr("x1",defns[bg].startx)
		.attr("y1",-defns[bg].starty)
		.attr("x2",defns[bg].endx)
		.attr("y2",-defns[bg].endy)
		.attr("style", "stroke:#" + "000000".slice(hexColor.length) + hexColor + ";stroke-width:" + defns[bg].width);
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
      h = y-100-ngap;
    d3.select('#' + this.port + '_diag').attr("width",w).attr("height",h);

    // problem: getbbox returns 0s if diagram not visible
    // -- so need to either raise any notebook tabs I am
    // in, or do this inline -- works fine if done here!
    if (this.scaleGrp.attr("transform") == null) {
	bbox = this.scaleGrp[0][0].getBBox();
	// console.log(JSON.stringify(bbox));
	if (bbox.width==0) return;
	initScale = w/bbox.width;
	this.diagZoom.translate([-initScale*bbox.x,-initScale*bbox.y])
	    .scale(initScale);
	grpAttr = "translate("+-initScale*bbox.x+","+-initScale*bbox.y+
	    ")scale("+initScale+","+initScale+")";
	this.scaleGrp.attr("transform",grpAttr);
    }
}

function ToRadians (axis) {
    fl = parseFloat(axis);
    if (!isNaN(fl))
	return fl;
    else if ((ct = ["e", "ne", "n", "nw", "w", "sw", "s", "se"].indexOf(axis)) > -1)
	return ct*6.28/8;
    else if ((ct = ["3h", "2h", "1h", "12h", "11h", "10h", "9h", "8h", "7h", "6h", "5h", "4h"].indexOf(axis)) > -1)
	return ct*6.28/12;
    else
	console.log("Unrecognized axis " + axis);
}
