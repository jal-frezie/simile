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
    this.updated = false;

    that = this;
    var animate = function () {
	window.requestAnimFrame( animate );
	// cube.rotation.x += 0.1; cube.rotation.y += 0.1;
	// if ("tabs-" + $( "#tabs" ).tabs("option","active") == port)
	// above dodgy because tab id can change (eg if another deleted)
	if ($('#' + that.port + '_div').width() && that.updated) {
		renderer.render(scene, camera);
		that.updated = false;
	    }
	controls.update();
    };
    var waggle = function() {
	that.updated = true;
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
    <hr>\
    <li id='ellipses'><a href='javascript:void(0);'>Ellipse</a></li>\
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
				   ["colour","back"]]};
    that.template = allTemplates[type];
    that.newComps = [];
    MakeSelection(that, type);
}

function AddTemplateToScene (that, template, newComps) {
    template.push({}); // new empty display object list
    var newData = js_from_tgts(newComps);
//      for (var i=0; i<newComps.length; ++i) {
//	  newDataArr.push(js_from_local_model(newComps[i], 1000000))
//      }
//     $.post('model_action.php', {"base":fileBase, "act":"Query",
// 				"note":JSON.stringify(newComps)},
// 	   function(newDataCode) {
	       oldState = that.State;
	       that.State = [template]; // New items only
	       
// 	       newDataArr = JSON.parse(newDataCode);
//	       newData = {};
//	       for (j=0; j<newComps.length; ++j) {
//		   nItm = newComps[j]
//		   newData[nItm] = newDataArr[j];
		   // do not use popups they may be incomplete
//	       }
	       that.display(parseFloat($("#ct").val()),newData,false),
	       that.State = oldState;
	       that.State.push(template);
// 	   }); // Query
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

Shapes3D.prototype.display = function (time, latest, connect) {
    lolliCount = 0;
    lolliCols = [0x00ff00, 0xf1da7e, 0x36b694, 0xec9844, 0x94a646, 0xd9d095];
    // now add new ones
    for (j=0; j<this.State.length; ++j) {
	instruct = this.State[j];
	switch (instruct[0]) {
	case "spheres":
	    // first remove old items
	    for (var old in instruct[6]) {
		this.scene.remove(instruct[6][old]);
		delete(instruct[6][old]);
	    }
	    instruct[6] = {};

	    defns = {};
	    for (i=1;i<5;++i) {
		defns[["n","x","y","z","r"][i]] = flatten("s",latest[instruct[i]]);
	    }
	    nC = parseInt('0x' + instruct[5]);
	    var sphereMaterial = new THREE.MeshLambertMaterial( {color: nC} ); 
	    var sphereGeometry = new THREE.SphereGeometry(1.0, 32, 16 ); 
	    for (iV in defns.r) {
		if (defns.r[iV] < 1) continue;
		// Sphere parameters: radius, segments along width, segments along height
	// use a "lambert" material rather than "basic" for realistic lighting.
		    //   (don't forget to add (at least one) light!)
		    
		var sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
		sphere.position.set(defns.x[iV], defns.z[iV], defns.y[iV]);
		sphere.scale.set(defns.r[iV], defns.r[iV], defns.r[iV]);
		instruct[6][iV] = sphere;
		this.scene.add(sphere);
	    }
	    break;
	case "lines":
	    for (var old in instruct[9]) {
		this.scene.remove(instruct[9][old]);
		delete(instruct[9][old]);
	    }
	    instruct[9] = {};

	    defns = {};
	    for (i=1;i<8;++i) {
		defns[["n","sx","sy","sz","fx","fy","fz","w"][i]] = flatten("l",latest[instruct[i]]);
	    }
	    nC = parseInt('0x' + instruct[8]);
	    var lineGeometry = new THREE.CylinderGeometry(0.5,0.5,1.0);
	    var lineMaterial = new THREE.MeshLambertMaterial( {color: nC} );
	    for (iV in defns.w) {
		if (defns.w[iV] < 1) continue;

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
		var line = new THREE.Mesh(lineGeometry, lineMaterial);
		line.position.set((defns.fx[iV]+defns.sx[iV])/2,
				  (defns.fz[iV]+defns.sz[iV])/2,
				  (defns.fy[iV]+defns.sy[iV])/2);
		xyExt = Math.pow(defns.fx[iV]-defns.sx[iV],2)+
		    Math.pow(defns.fy[iV]-defns.sy[iV],2);
		line.scale.set(defns.w[iV], Math.sqrt(xyExt +
					 Math.pow(defns.fz[iV]-defns.sz[iV],2)),
			       defns.w[iV]);
		line.rotation.set(0,
				  -Math.atan2(defns.fy[iV]-defns.sy[iV],
					     defns.fx[iV]-defns.sx[iV]),
				  -Math.atan2(Math.sqrt(xyExt), defns.fz[iV]-defns.sz[iV]));
		instruct[9][iV] = line;
		this.scene.add(line);
	    }
	    break;
	case "polygons":
	    for (var old in instruct[6]) {
		this.scene.remove(instruct[6][old]);
		delete(instruct[6][old]);
	    }
	    instruct[6] = {};
	    defns = {};
	    for (i=1;i<4;++i) {
		defns[["n","xs","ys","zs"][i]] =
		    flatten_to_array("p", latest[instruct[i]]);
	    }
	    nC = parseInt('0x' + instruct[4]);
	    eC = parseInt('0x' + instruct[5]);
	    var polyMaterial = new THREE.MeshLambertMaterial( {color: eC} ); 
	    
	    for (var face in defns.xs) {
		var polyGeometry = new THREE.Geometry();
		var vc = 0
		for (var vertex in defns.xs[face]) {
		    polyGeometry.vertices.push(new THREE.Vector3(
			defns.xs[face][vertex],
			defns.zs[face][vertex],
			defns.ys[face][vertex]));
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
		instruct[6][face] = poly;
	    }
	    break;
	case "lollipops":
	    // first remove old items
	    for (var old in instruct[4]) {
		this.scene.remove(instruct[4][old]);
		delete(instruct[4][old]);
	    }
	    instruct[4] = {};

	    defns = {};
	    for (i=1;i<4;++i) {
		defns[["n","x","y","h"][i]] = flatten("p",latest[instruct[i]]);
	    }
	    nC = lolliCols[lolliCount++];
	    var sphereMaterial = new THREE.MeshLambertMaterial( {color: nC} ); 
	    var sphereGeometry = new THREE.SphereGeometry(1.0, 32, 16 ); 
	    var lineMaterial = new THREE.MeshLambertMaterial({color: 0x084000});
	    var lineGeometry = new THREE.CylinderGeometry(0.5,0.5,1.0);
	    for (iV in defns.h) {
		if (defns.h[iV] < 1) continue;
		// Sphere parameters: radius, segments along width, segments along height
	// use a "lambert" material rather than "basic" for realistic lighting.
		    //   (don't forget to add (at least one) light!)
		    
		var sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
		sphere.position.set(defns.x[iV], 3*defns.h[iV]/2, defns.y[iV]);
		sphere.scale.set(defns.h[iV]/2, defns.h[iV]/2, defns.h[iV]/2);
		instruct[4][iV+"s"] = sphere;
		this.scene.add(sphere);

		var line = new THREE.Mesh(lineGeometry, lineMaterial);
		line.position.set(defns.x[iV], defns.h[iV]/2, defns.y[iV]);
		line.scale.set(2, defns.h[iV], 2);
		instruct[4][iV+"l"] = line;
		this.scene.add(line);
	    }
	    break;
	case "ellipses":
	    for (var old in instruct[11]) {
		this.scene.remove(instruct[11][old]);
		delete(instruct[11][old]);
	    }
	    instruct[11] = {};

	    defns = {};
	    for (i=1;i<9;++i) {
		defns[["n","cx","cy","cz","r","e","rx","ry","rz"][i]] =
		    flatten("l",latest[instruct[i]]);
	    }
	    fC = parseInt('0x' + instruct[9]);
	    bC = parseInt('0x' + instruct[10]);
	    var circleGeom = new THREE.CircleGeometry(1,24);
	    var circleMat = new THREE.MeshLambertMaterial( {color : fC});
	    var circleBack = new THREE.MeshLambertMaterial( {color : bC});
	    for (iV in defns.r) {
		if (defns.r[iV] < 1) continue;

		var circle = new THREE.Mesh(circleGeom, circleMat);
		circle.position.set(defns.cx[iV], defns.cz[iV], defns.cy[iV]);
		circle.scale.set(defns.r[iV], defns.r[iV]/defns.e[iV], 1);
		circle.rotation.set(-defns.rx[iV]-1.57, -defns.ry[iV],
				    -defns.rz[iV], 'XZY');
		instruct[11][iV + ",f"] = circle;
		this.scene.add(circle);

		circle = new THREE.Mesh(circleGeom, circleBack);
		circle.position.set(defns.cx[iV], defns.cz[iV], defns.cy[iV]);
		circle.scale.set(defns.r[iV], defns.r[iV]/defns.e[iV], 1);
		circle.rotation.set(-defns.rx[iV]+1.57, defns.ry[iV],
				    defns.rz[iV], 'XZY');
		instruct[11][iV + ",b"] = circle;
		this.scene.add(circle);
	    }
	    break;

	default:
	    alert("Unrecognized item type: " + instruct[0]);
	}
    }
    this.updated = true;
}

Shapes3D.prototype.resize = function (x,y) {
    this.renderer.setSize(x-50, y-120);
}

