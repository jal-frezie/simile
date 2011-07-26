use.simile.at <- function(path) {
  tcl("set", "::loadedFromR", 1) # lets Tcl client know R is using it
  tcl("source", file.path(.find.package(package = "Simile"), "exec",
                        "client5d.tcl"))
  tcl("UseSimileAt", path)
}

load.model <- function(model.file) {
  tcl("loadmodel", model.file, "R")
}

list.objects <- function(model.handle) {
  as.character(tcl("ListObjPaths", model.handle))
}

get.model.property <- function(model.handle, obj, action) {
  tcl.result <- tcl("GetModelProperty", model.handle, obj, action)
  if (any(c("Dims")==action)) {
# may be more integer cases
    with.trailing.zero <- as.integer(tcl.result)
    with.trailing.zero[-length(with.trailing.zero)] # removes it
  } else if (any(c("MinVal","MaxVal")==action)) {
# may be more integer cases
    as.real(tcl.result)
  } else {
    as.character(tcl.result)
  }
}

create.model <- function(model.handle) {
  tcl("CreateModel", model.handle)
}

set.model.step <- function(instance.handle, step.level, step.duration) {
  tcl("c_setstepmodel", instance.handle, step.duration, step.level)
}

create.param.array <- function(instance.handle, param.name) {
  tcl("CreateParamArray", instance.handle, param.name)
}

set.model.parameter <- function(param.handle, values) {
  tcl("SetParamArrayFromFlatList", param.handle, values, dim(values))
}

consult.parameter.metafile <- function(instance.handle, param.file) {
  tcl("ConsultParameterMetafile", instance.handle, param.file)
}

reset.model <- function(instance.handle, t0, integration.method, depth) {
  tcl("ResetModel", instance.handle, t0, integration.method, depth)
}

execute.model <- function(instance.handle, integration.method, from, to,
                          error.limit, event.pauses) {
  tcl("ExecuteModel", instance.handle, integration.method, from, to,
                          error.limit, event.pauses)
}

#
tcl.paired.to.array <- function(paired, dims) {
  result <- rep(NA, times=prod(dims)) # sets all
  dim(result) <- dims
  subDims <- dims[-1] # removes first element
  for (posn in 1:dims[1]) {
    idx <- 2*posn-1
    member <- tcl("lindex", paired, idx)
    if (length(subDims)) {
      result[posn,] <- tcl.paired.to.array(member, subDims)
    } else {
      result[posn] <- as.real(member)
    }
  }
  result
}

get.value.array <- function(instance.handle, value.name) {
  paired <- tcl("GetPairedValues", instance.handle, value.name)
  i.m.list <- tcl("array", "get", "::modelTypes", instance.handle)
  dims <- get.model.property(tcl("lindex", i.m.list, 1), value.name, "Dims")
  if (length(dims)) {
    tcl.paired.to.array(paired, dims)
  } else {
    as.real(paired)
  }
}
