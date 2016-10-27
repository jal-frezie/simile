
function AddParamLineTo(parmTable, id, ParmTree, tool) {
 divis = ParmTree.indexOf("/", 1);
 if (divis>-1) {
    subParm = ParmTree.slice(1, divis);
    rows = $(parmTable).children("TBODY").children("[name='" + subParm + "']");
    if (rows.length) {
      cell = rows[0].firstChild;
      subParmTable = cell.firstChild;
    } else {
      row = parmTable.insertRow(-1);
      hdr = document.createElement('th');
      row.appendChild(hdr);
      if (tool == "slider") {
	  tabWidth = 3;
      } else {
	  tabWidth = 2;
      }
      hdr.colSpan = tabWidth;
      hdr.innerHTML = subParm;
      row = parmTable.insertRow(-1);
	row.setAttribute("name",subParm);
      cell = row.insertCell(-1);
      cell.colSpan = tabWidth;
      subParmTable = document.createElement("TABLE");
      subParmTable.setAttribute("border", 2);
      cell.appendChild(subParmTable);
    }
    return AddParamLineTo(subParmTable, id, ParmTree.slice(divis), tool);
  } else {
    row = parmTable.insertRow(-1);
    cell = row.insertCell(-1);
    label = document.createElement("LABEL");
    cell.appendChild(label);
    label.innerHTML = ParmTree.slice(1);
    cell = row.insertCell(-1);
    input = document.createElement("INPUT");
    cell.appendChild(input);
    if (tool == "slider") {
	min = model_json[id].min;
	max = model_json[id].max;
	input.insertAdjacentHTML('beforebegin', min);
	input.insertAdjacentHTML('afterend', max);
	if (model_json[id].type == "REAL") {
	    input.setAttribute("min", 0);
	    input.setAttribute("max", 1000);
	} else {
	    input.setAttribute("min", min);
	    input.setAttribute("max", max);
	}
	cell = row.insertCell(1);
	monitor = document.createElement("INPUT");
	monitor.setAttribute("type", "text");
	monitor.onkeydown = function (e) {
	    var evt = e || window.event;
	    // "e" is the standard behavior (FF, Chrome, Safari, Opera),
	    // while "window.event" (or "event") is IE's behavior
	    if ( evt.keyCode === 13 ) {
		id = evt.target.id.substr(4);
		slider = document.getElementById("rng_" +id);
		SetSliderValue(slider, id, evt.target.value);
		toModel(slider, id);
	    }
	};
	monitor.setAttribute("id", 'mtr_' + id);
	cell.appendChild(monitor);

	input.setAttribute("type", "range");
	if (runningInClient)
	    monitor.value = js_from_local_model(id, 1000);
	else
	    monitor.value = values_json[id];
	SetSliderValue(input, id, monitor.value);
        cb = new Function("zap", "transfer(zap.target, '" + id + "');");
	input.addEventListener("input", cb);
	cb = new Function("zap", "toModel(zap.target, '" + id + "');");
	input.addEventListener("change", cb);
    } else {
	input.setAttribute("type", "text");
    }
    return input;
  }
}      

function GetSliderValue(widget) {
    //    widget = document.getElementById("rng_" + id);
    id = widget.id.substr(4);
    if (model_json[id].type == "REAL") {
	return ((1000-widget.value)*model_json[id].min +
		widget.value*model_json[id].max)/1000;
    } else {
	return widget.value;
    }
}

function SetSliderValue(widget, id, value) {
    if (model_json[id].type == "REAL") {
	widget.value = 1000*(value-model_json[id].min)
	    /(model_json[id].max-model_json[id].min);
    } else {
	widget.value = value;
    }
}

function transfer(zapTgt, id) {
//    alert("zap " + zapTgt + " entry " + id);
    document.getElementById('mtr_' + id).value = GetSliderValue(zapTgt);
    toModel(zapTgt, id);
}

function Sliders (port) {
  this.port = port;
  this.tgts = [];
  this.status = "passive";

// Add a slider for each input deprecatedly using table for layout
    $('#' + this.port).html("<table id='slidertab' border='2'></table>");
  rangeTable = document.getElementById("slidertab"); // assume only one
  for (i=0;i<fvParms.length;i++) {
      id = fvParms[i];
      if (model_json[id].eval == "INPUT") {
	  input = AddParamLineTo(rangeTable, id, model_json[id].captpath, 
				 "slider");
	  input.setAttribute("id", 'rng_' + id);
      }
  }
}

Sliders.prototype.display = function  (time, latest, connect) {
}

Sliders.prototype.resize = function(x,y) {
}
