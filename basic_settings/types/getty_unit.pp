# Concrete text or serial getty instances, including systemd-escaped unit names, without templates or glob patterns.
type Basic_settings::Getty_unit = Pattern[/\A(?:getty|serial-getty)@(?:[\w:.-]|\\x[\da-fA-F]{2})+\.service\z/]
