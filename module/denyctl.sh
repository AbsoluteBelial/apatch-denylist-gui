#!/system/bin/sh
# denylist 后端：list | add PKG | del PKG | scan | backup
CFG=/data/adb/ap/package_config
TMP=$CFG.gui.tmp
BAKDIR=/data/adb/denylist_gui_bak

rewrite() { # $1=pkg $2=0/1  只改 exclude 字段，保留 allow(su 授权)/uid/sctx
  awk -F, -v P="$1" -v V="$2" 'BEGIN{OFS=","} $1==P{$2=V} {print}' "$CFG" > "$TMP" \
    && cat "$TMP" > "$CFG" && rm -f "$TMP"   # cat 覆盖写，保留原文件权限与 SELinux 上下文
}

backup_once() { # 每次开机首改前备份一次
  mkdir -p "$BAKDIR"
  mark="$BAKDIR/.boot_$(cat /proc/sys/kernel/random/boot_id)"
  [ -f "$mark" ] && return
  cp "$CFG" "$BAKDIR/package_config.$(date +%Y%m%d_%H%M%S)" && touch "$mark"
  ls -t "$BAKDIR"/package_config.* 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null  # 只留 10 份
}

case "$1" in
  list)
    # 输出 包名|是否隐藏(0/1)|类型(u=第三方 s=系统)
    awk -F, '$2==1{print $1}' "$CFG" 2>/dev/null | sort > /data/local/tmp/.dg_e
    pm list packages -3 2>/dev/null | sed 's/^package://' | sort > /data/local/tmp/.dg_u
    pm list packages -s 2>/dev/null | sed 's/^package://' | sort > /data/local/tmp/.dg_s
    awk 'FILENAME==ARGV[1]{e[$0]=1;next} FILENAME==ARGV[2]{print $0"|"(($0 in e)?1:0)"|u";next} {print $0"|"(($0 in e)?1:0)"|s"}' \
      /data/local/tmp/.dg_e /data/local/tmp/.dg_u /data/local/tmp/.dg_s
    rm -f /data/local/tmp/.dg_e /data/local/tmp/.dg_u /data/local/tmp/.dg_s
    ;;
  add)
    p="$2"; [ -z "$p" ] && { echo "ERR nopkg"; exit 1; }
    backup_once
    if grep -q "^$p," "$CFG"; then
      rewrite "$p" 1
    else
      uid=$(pm list packages -U 2>/dev/null | grep -E "^package:$p " | sed -E 's/.*uid:([0-9]+).*/\1/')
      [ -z "$uid" ] && uid=0
      echo "$p,1,0,$uid,0,u:r:untrusted_app:s0" >> "$CFG"
    fi
    echo OK
    ;;
  del)
    p="$2"; [ -z "$p" ] && { echo "ERR nopkg"; exit 1; }
    backup_once
    rewrite "$p" 0
    echo OK
    ;;
  scan)
    # 本次开机以来崩溃过的 App 包名，附崩溃类型
    logcat -b crash -d 2>/dev/null > /data/local/tmp/.dg_crash
    grep -oE ">>> [a-zA-Z0-9._]+ <<<|Process: [a-zA-Z0-9._]+" /data/local/tmp/.dg_crash \
      | sed -E 's/>>> //; s/ <<<//; s/Process: //' | grep '\.' | sort -u | while read -r p; do
        pm path "$p" >/dev/null 2>&1 || continue   # 只要已安装的 App
        t=other
        grep -A40 ">>> $p <<<" /data/local/tmp/.dg_crash | grep -q libpairipcore && t=pairip
        grep -A3 "Process: $p" /data/local/tmp/.dg_crash | grep -q TerminateException && t=rootcheck
        echo "$p|$t"
      done
    rm -f /data/local/tmp/.dg_crash
    ;;
  *) echo "usage: list|add PKG|del PKG|scan" ;;
esac
