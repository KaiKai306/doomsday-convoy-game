extends SceneTree
func _init():
 for path in ["user://probe","res://.godot/probe","C:/Users/t6275/AppData/Local/Temp/godot-save-probe"]:
  var mkdir_result=DirAccess.make_dir_recursive_absolute(path)
  var f=FileAccess.open(path+"/probe.txt",FileAccess.WRITE)
  print("PROBE ",path," mkdir=",mkdir_result," exists=",DirAccess.dir_exists_absolute(path)," open=",FileAccess.get_open_error()," valid=",f != null)
 var ff=FileAccess.open("user://probe.txt",FileAccess.WRITE)
 print("ROOT_WRITE ",ff != null," code ",FileAccess.get_open_error())
 var userdir=DirAccess.open("user://")
 print("DIRECT ",userdir.make_dir("probe2")," path ",userdir.get_current_dir())
 quit()

