// requestAnim shim layer by Paul Irish
window.requestAnimFrame = (function(){
    return  window.requestAnimationFrame       ||
	window.webkitRequestAnimationFrame ||
	window.mozRequestAnimationFrame    ||
	window.oRequestAnimationFrame      ||
	window.msRequestAnimationFrame     ||
	function(/* function */ callback, /* DOMElement */ element){
	    window.setTimeout(callback, 1000 / 60);
	};
})();

function Shapes3D (port) {
  this.port = port;
    this.tgts = [];
    this.State = [];
    this.showing = {};
  this.status = "displaying";
      w = 800;
//      w = parseInt(d3.select('#tabs').style('width'), 10)-50;
      h = 800;
//      h = notebookPaneHeight()-120;

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera( 75, w/h, 0.1, 1000 );
    var renderer = new THREE.WebGLRenderer();
    renderer.setSize( w, h );

    $('#' + port).html("<div id='" + port + "_drop2'></div>\
<div id='" + port + "_div'></div>");

    ShowMenuButton(this);
// demo dropdown 2 ---------------------------------------------------------

    document.getElementById(port + "_div").appendChild( renderer.domElement );

    // CONTROLS
    controls = new THREE.OrbitControls( camera, renderer.domElement );

	///////////
	// LIGHT //
	///////////
	
	// create a light
	var light = new THREE.PointLight(0xffffff);
	light.position.set(0,250,0);
	scene.add(light);
	var ambientLight = new THREE.AmbientLight(0x404040);
	scene.add(ambientLight);
	
	///////////
	// FLOOR //
	///////////
	
	// note: 4x4 checkboard pattern scaled so that each square is 25 by 25 pixels.
	var floorTexture = new THREE.ImageUtils.loadTexture( 'images/checkerboard.jpg' );
	floorTexture.wrapS = floorTexture.wrapT = THREE.RepeatWrapping; 
	floorTexture.repeat.set( 10, 10 );
	// DoubleSide: render texture on both sides of mesh
//    var floorMaterial = new THREE.MeshBasicMaterial( { map: floorTexture, side: THREE.DoubleSide, opacity: 0.75 } );
//	var floorGeometry = new THREE.PlaneGeometry(1000, 1000, 1, 1);
//	var floor = new THREE.Mesh(floorGeometry, floorMaterial);
//	floor.position.y = -0.5;
//	floor.rotation.x = Math.PI / 2;
//	scene.add(floor);

    // test some new shapes!

    var geometry = new THREE.CylinderGeometry( 5, 10, 50, 32 );
    var material = new THREE.MeshLambertMaterial( {color: 0xffff00, 
						transparent: true,
						opacity: 0.8} );
    var cylinder = new THREE.Mesh( geometry, material );
    cylinder.rotation.set(1,0,1);
//    scene.add( cylinder );
    
    var circleGeom = new THREE.CircleGeometry(500,24);
    var baseCirc = [{"col":0xff0000,"rot":[0,0]},
		    {"col":0x00ffff,"rot":[0,3.14]},
		    {"col":0x00ff00,"rot":[0,1.57]},
		    {"col":0xff00ff,"rot":[0,-1.57]},
		    {"col":0x0000ff,"rot":[-1.57,0]},
		    {"col":0xffff00,"rot":[1.57,0]}];
		    
    for (var i=0; i<baseCirc.length; ++i) {
	var circleMat = new THREE.MeshBasicMaterial( {map: floorTexture,
						      color : baseCirc[i].col, 
						      transparent: true,
						      opacity: 0.5});
	var circle = new THREE.Mesh(circleGeom, circleMat);
	circle.rotation.set(baseCirc[i].rot[0], baseCirc[i].rot[1], 0);
	scene.add(circle);
    }
    
    camera.position.set(250,100,250);
    camera.lookAt(scene.position);	

    this.scene = scene;
    this.camera = camera;
    this.renderer = renderer;
    this.updated = 0;

    that = this;
    var animate = function () {
	window.requestAnimFrame( animate );
	// cube.rotation.x += 0.1; cube.rotation.y += 0.1;
	// if ("tabs-" + $( "#tabs" ).tabs("option","active") == port)
	// above dodgy because tab id can change (eg if another deleted)
	if ($('#' + that.port + '_div').width() && that.updated) {
		renderer.render(scene, camera);
		--that.updated;
	    }

	controls.update();
    };
    var waggle = function() {
	that.updated = 1;
    };
    controls.addEventListener( 'change', waggle );
    animate();
}

function ShowMenuButton (that) {
    dropHandle = '#' + that.port + '_drop2';
    launchHandle = that.port + '_launcher2';
    menuHandle = that.port + '_menu2';
    $(dropHandle).html("\
  <div id='" + launchHandle + "_container'>\
    <button id='" + launchHandle + "'>Select new item type</button>\
  </div>\
  <ul id='" + menuHandle + "'>\
    <li id='spheres'><a href='javascript:void(0);'>Sphere</a></li>\
    <li id='lines'><a href='javascript:void(0);'>Line</a></li>\
    <li id='polygons'><a href='javascript:void(0);'>Polygon</a></li>\
    <li id='lollipops'><a href='javascript:void(0);'>Lollipop</a></li>\
    <li id='ellipses'><a href='javascript:void(0);'>Ellipse</a></li>\
    <li id='surface'><a href='javascript:void(0);'>Surface</a></li>\
  </ul>");
    
    $(dropHandle).jui_dropdown({
    launcher_id: launchHandle,
    launcher_container_id: launchHandle + '_container',
    menu_id: menuHandle,
    containerClass: 'container2',
      menuClass: 'menu2',
//    launcher_is_UI_button: false,
      onSelect: function(event, data) {
	  //      $("#result").text('index: ' + data.index + ' (id: ' + data.id + ')');
	  AddItem(that, data.id);
    }
  });
}

function AddItem (that, type) {
//    console.log('AI ' + JSON.stringify(that));
    // next make this look more like ZooXYZ.tcl
    var allTemplates = {"spheres":[["type","Select new item type"],
				  ["component","X positions"],
				  ["component","Y positions"],
				  ["component","Z positions"],
				  ["component","size values"],
				  ["colour","colour"]],
			"lines":[["type","Select new item type"],
				["component","start X positions"],
				["component","start Y positions"],
				["component","start Z positions"],
				["component","end X positions"],
				["component","end Y positions"],
				["component","end Z positions"],
				["component","width values"],
				["colour","colour"]],
			"polygons":[["type","Select new item type"],
				    ["component","X vertex position lists"],
				    ["component","Y vertex position lists"],
				    ["component","Z vertex position lists"],
				    ["colour", "outline"],
				    ["colour", "fill"]],
			"lollipops":[["type","Select new item type"],
				  ["component","X positions"],
				  ["component","Y positions"],
				  ["component","size values"]],
			"ellipses":[["type","Select new item type"],
				   ["component","centre X positions"],
				   ["component","centre Y positions"],
				   ["component","centre Z positions"],
				   ["component","length of major radii"],
				   ["component","eccentricities"],
				   ["component","X rotations"],
				   ["component","Y rotations"],
				   ["component","Z rotations"],
				   ["colour","front"],
				    ["colour","back"]],
			"surface":[["type","Select new item type"],
				   ["component","node X positions"],
				   ["component","node Y positions"],
				   ["component","node Z positions"],
				   ["colour", "outline"],
				   ["colour", "fill"]]};
    that.template = allTemplates[type];
    that.newComps = [];
    currentHelper = currentHelpers[that.port];
    MakeSelection(that, type);
}

function AddTemplateToScene (that, template, newComps) {
    template.push({}); // new empty display object list

    if (runningInClient) {
    // for client model execution
	var newData = js_from_tgts(newComps);
	that.displayOne(template, newData);
    } else {
	$.post('model_action.php', {"base":fileBase, "act":"Query",
				    "note":JSON.stringify(newComps)},
 	       function(newDataCode) {
		   newDataArr = JSON.parse(newDataCode);
 		   newData = {};
 		   for (j=0; j<newComps.length; ++j) {
 		       nItm = newComps[j]
 		       newData[nItm] = newDataArr[j];
		       // do not use popups they may be incomplete
		   }
		   that.displayOne(template, newData);
	       });
    }
    that.State.push(template);
    that.updated = 2;
}

function MakeSelection (that, selected) {
//    console.log('MS ' + JSON.stringify(that));
    dropHandle = '#' + that.port + '_drop2';
    for (i=0;i<that.template.length;i++) {
	code = ["type","component","colour"].indexOf(that.template[i][0]);
	if (code>-1) {
	    if (code == 1) { // component, put in list
		that.newComps.push(selected);
	    }
	    that.template[i] = selected;
	    break;
	}
    }
    i++;
    if (i == that.template.length) { // finished
	AddTemplateToScene(that, that.template, that.newComps);
	ShowMenuButton(that);
    } else {
	switch (that.template[i][0]) {
	case "component":
	    $(dropHandle).text('Click on component with ' + that.template[i][1] + ' of ' + that.template[0]);
	    break;
	case "colour":
	    $(dropHandle).text('Choose ' + that.template[i][1] + ' of ' + that.template[0] + ': '); // provide JSColor widget calling this back with colour
	    clr = document.createElement('INPUT')
	    // bind jscolor
	    var col = new jscolor.color(clr);
	    document.getElementById(that.port + '_drop2').appendChild(clr);
	    
	    var btn = document.createElement('button');
	    btn.innerHTML = 'OK';
	    btn.onclick = function(){
		MakeSelection(that, col.toString()); // no
		return false;
	    };
	    document.getElementById(that.port + '_drop2').appendChild(btn);
	    break;
	default:
	    console.log("Worng datum type: " + that.template[i][0]);
	}
    }   
}

Shapes3D.prototype.acceptClick = function (compId) {
    this.tgts.push(compId);
    MakeSelection(this, compId);
}

function nestedAtLeast(ob, depth) {
    if (depth == 0)
	return 1
    else if (typeof(ob) == "object")
    	for (subOb in ob)
	    return nestedAtLeast(subOb, depth-1);
    else
	return 0
}

function flattenAll(head, objs, depth) {
    var result = {};
    var	goOn = 0;
    
    for (var deeper in objs) {
	if (nestedAtLeast(objs[deeper], depth+1)) {
	    goOn = 1;
	    break;
	}
    }

    if (goOn) {
	for (var neck in objs[deeper]) {
	    var subObjs = {};
	    for (var obj in objs) {
		if (typeof (objs[obj]) == "object") {
		    subObjs[obj] = objs[obj][neck];
		} else {
		    subObjs[obj] = objs[obj];
		}
	    }
	    var iny = flattenAll(head,subObjs,depth);
	    for (var item in iny) {
		result[neck + ',' + item] = iny[item];
	    }
	}
    } else {
	result[head] = objs;
    }
    return result;
}

function addAsApprop(latest, arr) {
    if (latest[arr] != undefined) {
	return latest[arr];
    } else {
	return parseFloat(arr);
    }
}

function MakeColourKey(spec, modVals, legend) {
    if (spec.constructor === Array) { // colour from value
	for (i=0;i<spec[2].length;++i) {
	    legend.push(new THREE.MeshLambertMaterial( {color: spec[2][i]} ));
	}
	return modVals[spec[1]];
    } else { // colour constant
	legend.push(new THREE.MeshLambertMaterial({color:spec}));
	return 0;
    }
}

Shapes3D.prototype.display = function (time, latest, connect) {
    lolliCount = 0;
    // now add new ones
    for (var j=0; j<this.State.length; ++j) {
	this.displayOne(this.State[j], latest);
    }
    this.updated = 2;
}

var lolliCount;
Shapes3D.prototype.displayOne = function(instruct, latest) {
    var lolliCols = [0x00ff00, 0xf1da7e, 0x36b694, 0xec9844, 0x94a646, 0xd9d095];
    switch (instruct[0]) {
    case "spheres":
	// first remove old items
	for (var old in instruct[6]) {
	    this.scene.remove(instruct[6][old]);
	    delete(instruct[6][old]);
	}
	instruct[6] = {};
	
	allDefns = {};
	for (i=1;i<5;++i) {
	    allDefns[["n","x","y","z","r"][i]] = addAsApprop(latest, instruct[i]);
	}
	sphereMats = [];
	allDefns.c = MakeColourKey(instruct[5], latest, sphereMats);
	defns = flattenAll("s", allDefns, 0);
	var sphereGeometry = new THREE.SphereGeometry(1.0, 32, 16 ); 
	for (i in defns) {
	    defn = defns[i];
	    if (defn.r < 1) continue;
	    // Sphere parameters: radius, segments along width, segments along height
	    // use a "lambert" material rather than "basic" for realistic lighting.
	    //   (don't forget to add (at least one) light!)
	    
	    var sphere = new THREE.Mesh(sphereGeometry, sphereMats[defn.c]);
	    sphere.position.set(defn.x, defn.z, defn.y);
	    sphere.scale.set(defn.r, defn.r, defn.r);
	    instruct[6][i] = sphere;
	    this.scene.add(sphere);
	}
	break;
    case "lines":
	for (var old in instruct[9]) {
	    this.scene.remove(instruct[9][old]);
	    delete(instruct[9][old]);
	}
	instruct[9] = {};
	
	allDefns = {};
	for (i=1;i<8;++i) {
	    allDefns[["n","sx","sy","sz","fx","fy","fz","w"][i]] = addAsApprop(latest, instruct[i]);
	}
	lineMats = [];
	allDefns.c = MakeColourKey(instruct[8], latest, lineMats);
	defns = flattenAll("l", allDefns, 0);
	var lineGeometry = new THREE.CylinderGeometry(0.5,0.5,1.0);
	for (i in defns) {
	    defn = defns[i];
	    if (defn.w < 1) continue;

	/* Old version: used lineGeometry, which lacks width in Windows
		var lineMaterial = new THREE.LineBasicMaterial(
		    {color: nC,	linewidth: defns.w[iV]} ); 
		var lineGeometry = new THREE.Geometry();
		lineGeometry.vertices.push(
		    new THREE.Vector3(defns.sx[iV], defns.sz[iV], defns.sy[iV]),
		    new THREE.Vector3(defns.fx[iV], defns.fz[iV], defns.fy[iV])
		);
		var line = new THREE.Line(lineGeometry, lineMaterial);

	New version uses cylinders */
	    var line = new THREE.Mesh(lineGeometry, lineMats[defn.c]);
	    line.position.set((defn.fx+defn.sx)/2,
			      (defn.fz+defn.sz)/2,
			      (defn.fy+defn.sy)/2);
	    xyExt = Math.pow(defn.fx-defn.sx,2)+ Math.pow(defn.fy-defn.sy,2);
	    line.scale.set(defn.w, Math.sqrt(xyExt +
					 Math.pow(defn.fz-defn.sz,2)),
			   defn.w);
	    line.rotation.set(0, -Math.atan2(defn.fy-defn.sy, defn.fx-defn.sx),
			      -Math.atan2(Math.sqrt(xyExt), defn.fz-defn.sz));
	    instruct[9][i] = line;
	    this.scene.add(line);
	}
	break;
    case "polygons":
	for (var old in instruct[6]) {
	    this.scene.remove(instruct[6][old]);
	    delete(instruct[6][old]);
	}
	instruct[6] = {};
	allDefns = {};
	for (i=1;i<4;++i) {
	    allDefns[["n","xs","ys","zs"][i]] = addAsApprop(latest,instruct[i]);
	}
	polyMats = edgeMats = [];
	allDefns.n = MakeColourKey(instruct[4], latest, polyMats);
	allDefns.e = MakeColourKey(instruct[4], latest, edgeMats);
	defns = flattenAll("p", allDefns, 1);
	    
	for (i in defns) {
	    defn = defns[i];
	    var polyGeometry = new THREE.Geometry();
	    var vc = 0
	    for (var vertex in defn.xs) {
		polyGeometry.vertices.push(new THREE.Vector3(
		    defn.xs[vertex],
		    defn.zs[vertex],
		    defn.ys[vertex]));
		++vc;
		if (vc>2) {
		    var newFace = new THREE.Face3(0, vc-2, vc-1);
		    // newFace.color = nC;
		    polyGeometry.faces.push(newFace);
		}
	    }
	    // need these bits to get lighting fx to work
	    polyGeometry.computeFaceNormals ();
	    polyGeometry.computeVertexNormals ();
	    poly = new THREE.Mesh(polyGeometry, polyMaterial);
	    this.scene.add(poly);
	    instruct[6][i] = poly;
	}
	break;
	case "lollipops":
	    // first remove old items
	    for (var old in instruct[4]) {
		this.scene.remove(instruct[4][old]);
		delete(instruct[4][old]);
	    }
	    instruct[4] = {};

	    allDefns = {};
	    for (i=1;i<4;++i) {
		allDefns[["n","x","y","h"][i]] = latest[instruct[i]];
	    }
	    nC = lolliCols[lolliCount++];
	    var sphereMaterial = new THREE.MeshLambertMaterial( {color: nC} ); 
	    var sphereGeometry = new THREE.SphereGeometry(1.0, 32, 16 ); 
	    var lineMaterial = new THREE.MeshLambertMaterial({color: 0x084000});
	    var lineGeometry = new THREE.CylinderGeometry(0.5,0.5,1.0);
	defns = flattenAll("o", allDefns, 0);
	for (i in defns) {
	    defn = defns[i];
		if (defn.h < 1) continue;
		// Sphere parameters: radius, segments along width, segments along height
	// use a "lambert" material rather than "basic" for realistic lighting.
		    //   (don't forget to add (at least one) light!)
		    
		var sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
		sphere.position.set(defn.x, 3*defn.h/2, defn.y);
		sphere.scale.set(defn.h/2, defn.h/2, defn.h/2);
		instruct[4][i+"s"] = sphere;
		this.scene.add(sphere);

		var line = new THREE.Mesh(lineGeometry, lineMaterial);
		line.position.set(defn.x, defn.h/2, defn.y);
		line.scale.set(2, defn.h, 2);
		instruct[4][i+"l"] = line;
		this.scene.add(line);
	    }
	    break;
    case "ellipses":
	for (var old in instruct[11]) {
	    this.scene.remove(instruct[11][old]);
	    delete(instruct[11][old]);
	}
	instruct[11] = {};
	
	allDefns = {};
	for (i=1;i<9;++i) {
	    allDefns[["n","cx","cy","cz","r","e","rx","ry","rz"][i]] =
		addAsApprop(latest, instruct[i]);
	}
	frontMats = backMats = [];
	allDefns.f = MakeColourKey(instruct[9], latest, frontMats);
	allDefns.b = MakeColourKey(instruct[10], latest, backMats);

	var circleGeom = new THREE.CircleGeometry(1,24);
	defns = flattenAll("e", allDefns, 0);
	for (i in defns) {
	    defn = defns[i];
	    if (defn.r < 1) continue;

	    var circle = new THREE.Mesh(circleGeom, frontMats[defn.f]);
	    circle.position.set(defn.cx, defn.cz, defn.cy);
	    circle.scale.set(defn.r, defn.r/defn.e, 1);
	    circle.rotation.set(-defn.rx-1.57, -defn.ry, -defn.rz, 'XZY');
	    instruct[11][i + ",f"] = circle;
	    this.scene.add(circle);

	    circle = new THREE.Mesh(circleGeom, backMats[defn.b]);
	    circle.position.set(defn.cx, defn.cz, defn.cy);
	    circle.scale.set(defn.r, defn.r/defn.e, 1);
	    circle.rotation.set(-defn.rx+1.57, defn.ry, defn.rz, 'XZY');
	    instruct[11][i + ",b"] = circle;
	    this.scene.add(circle);
	}
	break;
    case "surface":
	// if (this.updated == 1) break;
	// halfway through draw process -- bad idea to skip, it may be last move
	    fC = new THREE.Color(parseInt('0x' + instruct[5]));
	    // "wireframe texture"
	    var wireTexture = new THREE.ImageUtils.loadTexture( 'images/square.png' );
	    wireTexture.wrapS = wireTexture.wrapT = THREE.RepeatWrapping; 
	    wireTexture.repeat.set( 40, 40 );
	    wireMaterial = new THREE.MeshBasicMaterial( { color: parseInt('0x' + instruct[4]), map: wireTexture, vertexColors: THREE.VertexColors, side:THREE.DoubleSide } );
	    wireMaterial.map.repeat.set( 25, 40 );

	    this.latestXs = latest[instruct[1]];
	    this.latestYs = latest[instruct[2]];
	    this.latestZs = latest[instruct[3]];

	    var outerKeys = Object.keys(this.latestZs);
	    this.outerDim = outerKeys.length;
	    var innerKeys = Object.keys(this.latestZs[outerKeys[0]]);
	    this.innerDim = innerKeys.length;

	    that = this; // for use inside function
	    meshFunction = function(u0, v0) 
	    {
		var u = (Math.round(u0*(that.outerDim-1))+1).toString();
		var v = (Math.round(v0*(that.innerDim-1))+1).toString();
		var x = that.latestXs[u][v];
		var y = that.latestYs[u][v];
		var z = that.latestZs[u][v];
		return new THREE.Vector3(x, z, y);
	    };
	
	    graphGeometry = new THREE.ParametricGeometry( meshFunction, this.outerDim-1, this.innerDim-1, true );
	    for ( var mi = 0; mi < graphGeometry.faces.length; mi++ ) 
	    {
		face = graphGeometry.faces[ mi ];
		numberOfSides = ( face instanceof THREE.Face3 ) ? 3 : 4;
		for( var mj = 0; mj < numberOfSides; mj++ ) 
		{
		    face.vertexColors[ mj ] = fC;
		}
	    }

	    graphMesh = new THREE.Mesh( graphGeometry, wireMaterial );
	    graphMesh.doubleSided = true;
	    for (var old in instruct[6]) {
		this.scene.remove(instruct[6][old]);
	    }
	instruct[6] = {};
	this.scene.add(graphMesh);
	instruct[6].only = graphMesh;
	break;
    default:
	alert("Unrecognized item type: " + instruct[0]);
    }
}
    
Shapes3D.prototype.resize = function (x,y) {
    this.renderer.setSize(x-50, y-120);
}

