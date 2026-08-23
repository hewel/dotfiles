function nosleep --description 'Disable automatic suspend on Arch Linux, but allow display off'
    set -l unit nosleep.service
    set -l profile_state_file "$XDG_RUNTIME_DIR/nosleep-prev-power-profile"

    if systemctl --user --quiet is-active $unit
        echo "自动休眠已经关闭中；显示器自动关闭不受此命令控制。"
        systemd-inhibit --list --no-pager | string match -i '*nosleep*'
        if command -q powerprofilesctl
            echo "当前电源配置：" (powerprofilesctl get)
        end
        return 0
    end

    # Remember current profile so sleepok can restore it
    if command -q powerprofilesctl
        set -l current (powerprofilesctl get 2>/dev/null)
        if test -n "$current"
            echo $current >$profile_state_file
        end
        if test "$current" != power-saver
            powerprofilesctl set power-saver
            and echo "电源配置已切换为 power-saver（原: $current）。"
            or echo "警告：无法切换电源配置为 power-saver。" >&2
        else
            echo "电源配置已是 power-saver。"
        end
    end

    systemd-run --user \
                --unit=nosleep \
                --collect \
                --property=Type=exec \
                --description='Prevent system suspend, allow display power saving' \
                /usr/bin/systemd-inhibit \
                    --what=sleep \
                    --mode=block \
                    --who=(whoami) \
                    --why='nosleep from fish' \
                    /usr/bin/sleep infinity

    echo "已关闭系统自动休眠；显示器仍可按桌面电源设置自动关闭。恢复请运行：sleepok"
end
