extends Node

signal changed(activo: bool)

var activas: bool = true:
	set(v):
		if activas == v: return
		activas = v
		changed.emit(v)
