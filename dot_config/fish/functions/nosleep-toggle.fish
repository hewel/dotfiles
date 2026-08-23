function nosleep-toggle --description 'Toggle automatic suspend inhibition'
    if systemctl --user --quiet is-active nosleep.service
        sleepok
    else
        nosleep
    end
end
