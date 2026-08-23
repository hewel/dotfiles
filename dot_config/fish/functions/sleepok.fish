function sleepok --description 'Re-enable automatic suspend'
    set -l unit nosleep.service
    set -l profile_state_file "$XDG_RUNTIME_DIR/nosleep-prev-power-profile"

    if systemctl --user --quiet is-active $unit
        systemctl --user stop $unit
        echo "已恢复系统默认休眠设置。"
    else
        echo "nosleep 当前没有运行。"
    end

    # Restore previous power profile if we saved one
    if command -q powerprofilesctl; and test -f $profile_state_file
        set -l previous (string trim < $profile_state_file)
        rm -f $profile_state_file
        if test -n "$previous"
            set -l current (powerprofilesctl get 2>/dev/null)
            if test "$current" != "$previous"
                powerprofilesctl set $previous
                and echo "电源配置已恢复为 $previous。"
                or echo "警告：无法恢复电源配置为 $previous。" >&2
            else
                echo "电源配置保持 $current。"
            end
        end
    end
end
