SKIPUNZIP=0
ui_print "- Denylist GUI"
ui_print "- 安装后在 模块 -> Denylist GUI -> 打开 使用"
ui_print "- After install: Modules -> Denylist GUI -> Open (WebUI)"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/denyctl.sh" 0 0 0755
