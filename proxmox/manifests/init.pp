
class proxmox() {

    case $basic_settings::debianname {
        'bookworm': {
            $kernel = '6.2'
        }
        default:  {
            $kernel = undef
        }
    }

    if ($kernel) {
        /* Install proxmox  */
        package { ["pve-kernel-${kernel}"]:
            ensure  => installed
        }
    }
}
