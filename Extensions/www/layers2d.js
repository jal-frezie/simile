function Layers2D (port) {
  this.port = port;
    this.tgts = [];
    this.State = [];
    this.scaleGrp = d3.select('#' + port).append("svg")
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
    layerSpec.gLayer = this.scaleGrp.append("g");
    for (var i=0; i<state.length;i+=2) {
	if (type == "::similescript::Polygon20131026") // indices start /WIN/,
	    state[i] = state[i].substr(6);
	possCapt = tclListOfDimty(state[i+1],1);
	if (possCapt[0][0] == "/") { // its a capt path
	    state[i+1] = idFromCapt(possCapt.join(" "));
	    this.tgts.push(state[i+1]);
	}
	layerSpec[state[i]] = state[i+1];
    }
    var endComps = this.tgts.length;
    
    // now do any one-off processing a new layer requires
    switch (type) {
    case "::similescript::Polygon20131026": // and maybe others
	swatArr = [];
	for (var i=0; i<=layerSpec.nswatches; ++i)
	    swatArr.push(layerSpec["c" + i]);
	layerSpec.cMap = ColorMapFromSwatches(swatArr);
    }
    
    var layerIndex = this.State.length;
    this.State.push(layerSpec);
    var that = this;
    $.post('model_action.php', {"base":fileBase, "act":"Query",
				"note":JSON.stringify(this.tgts.slice(startComps, endComps))},
	   function(resp) {
	       responses = JSON.parse(resp);
	       sorted = {};
	       for (var i=startComps; i<endComps; ++i)
		   sorted[that.tgts[i]] = responses[i-startComps];
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
    case "::similescript::Polygon20131026":
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

